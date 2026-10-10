require "active_support/testing/time_helpers"

# ローカル確認用のサンプルデータを作る（bin/rails dev:sample_data から呼ぶ）。
# seed（管理者・ゲスト・機体マスタ・絵文字）が入った状態で実行する前提。
# 乱数の種を固定しているので、同じ機体マスタなら毎回同じデータになる。機体は名前で決め打ちせず、
# その時点の機体マスタから選ぶ（機体が増えても修正は不要）。
# ローテーションの生成・結果の記録・次の試合へ進む・スキップ・次周の作成は本番と同じ処理を使う。
# config/discord.local.yml があれば、テスト用の Discord の投稿先も設定する
class SampleData
  include ActiveSupport::Testing::TimeHelpers

  SEED = 20261010
  PASSWORD = "password"
  MATCH_INTERVAL = 4.minutes
  # 詳細統計（配信映像の解析結果）を入れる試合の割合
  STATS_RATIO = 0.7

  # username, nickname, お気に入り機体の数
  USERS = [
    [ "sample_a", "サンプルA", 18 ],
    [ "sample_b", "サンプルB", 6 ],
    [ "sample_c", "サンプルC", 3 ],
    [ "sample_d", "サンプルD", 1 ],
    [ "sample_e", "サンプルE", 0 ],
    [ "sample_f", "サンプルF", 10 ]
  ].freeze

  # 過去のイベント: 何日前、参加人数、周回数
  PAST_EVENTS = [
    [ 42, 4, 2 ],
    [ 28, 5, 2 ],
    [ 14, 6, 1 ]
  ].freeze

  # テスト用の Discord の設定（Git の管理対象外）。書き方は config/discord.local.yml.example
  DISCORD_CONFIG_PATH = Rails.root.join("config/discord.local.yml")
  DISCORD_DEFAULT_KEY = "default"

  Summary = Struct.new(:users, :events, :matches, :discord_channels, keyword_init: true)

  # past_events: テストでは少なくして時間を短くする
  def initialize(random: Random.new(SEED), past_events: PAST_EVENTS, discord_config_path: DISCORD_CONFIG_PATH)
    @random = random
    @past_events = past_events
    @discord_config_path = discord_config_path
  end

  def call
    raise "機体マスタが空です。先に bin/rails db:seed を実行してください" if MobileSuit.none?

    # 試合の時刻をずらして記録するため、ずらす前の現在時刻を基準にする
    @now = Time.current
    users = create_users
    past_events.each.with_index(1) { |(days_ago, player_count, rounds), number| create_past_event(number, days_ago, users.first(player_count), rounds) }
    create_today_event(users)
    create_reactions_and_favorites(users)
    create_announcement
    create_discord_channels

    Summary.new(users: users.size, events: Event.count, matches: Match.count, discord_channels: DiscordChannel.count)
  ensure
    travel_back
  end

  private

  attr_reader :random, :now, :past_events, :discord_config_path

  def create_users
    USERS.map do |username, nickname, favorite_count|
      user = User.create!(username: username, nickname: nickname, password: PASSWORD, password_confirmation: PASSWORD)
      favorite_suits(favorite_count).each_with_index do |suit, slot|
        user.user_favorite_suits.create!(mobile_suit: suit, slot: slot)
      end
      user
    end
  end

  # 高コスト寄りに選ぶ（実際のお気に入りの傾向に合わせる）
  def favorite_suits(count)
    suits = MobileSuit.order(:id).to_a
    suits.sort_by { |suit| -suit.cost * random.rand }.first(count)
  end

  def create_past_event(number, days_ago, players, rounds)
    held_on = now.to_date - days_ago
    travel_to(held_on.in_time_zone.change(hour: 19))
    event = Event.create!(name: "サンプル対戦会 ##{number}", held_on: held_on, description: "ローカル確認用のサンプルイベントです。")

    rotation = start_rotation(event, players)
    rounds.times do |round|
      rotation = next_round(rotation) if round.positive?
      record_until(rotation, rotation.rotation_matches.count)
    end
  end

  # 今日のイベント: 入力済み・未入力・スキップ・現在・予定の試合が揃った状態で止める
  def create_today_event(users)
    travel_to(now.beginning_of_minute - 12 * MATCH_INTERVAL)
    event = Event.create!(name: "サンプル対戦会（開催中）", held_on: now.to_date, description: "進行中のローテーションを確認するためのサンプルイベントです。")
    rotation = start_rotation(event, users)

    record_until(rotation, 4)
    advance { manager(rotation).next_match!(expected_index: rotation.current_match_index) }
    record_until(rotation, 6)
    advance { manager(rotation).skip_match!(expected_index: rotation.current_match_index) }
    record_until(rotation, 8)
    advance { manager(rotation).next_match!(expected_index: rotation.current_match_index) }
    record_until(rotation, 10)
  end

  def start_rotation(event, players)
    rotation = event.rotations.create!(round_number: 1)
    succeed!(manager(rotation).generate_matches!(player_ids: players.map(&:id)))
    succeed!(manager(rotation).activate!)
    rotation
  end

  def next_round(rotation)
    succeed!(manager(rotation.reload).copy_for_next_round!).new_rotation
  end

  # 現在の試合の結果を、match_index が limit になるまで（または全試合を入力し終えるまで）記録する
  def record_until(rotation, limit)
    loop do
      rotation.reload
      break if !rotation.is_active? || rotation.current_match_index >= limit

      rotation_match = rotation.rotation_matches.find_by!(match_index: rotation.current_match_index)
      advance do
        manager(rotation).record_current_match!(
          winning_team: random.rand(1..2),
          suit_ids: pick_suits(rotation_match),
          expected_index: rotation.current_match_index
        )
      end
      fill_stats(rotation_match.reload.match) if random.rand < STATS_RATIO
    end
  end

  def advance
    result = yield
    succeed!(result)
    travel MATCH_INTERVAL
    result
  end

  def manager(rotation)
    RotationWorkflowManager.new(rotation: rotation, random: random)
  end

  def succeed!(result)
    raise "サンプルデータの作成に失敗しました: #{result.error_message}" unless result.success?

    result
  end

  # 7 割はお気に入りから、残りは全機体から選ぶ
  def pick_suits(rotation_match)
    RotationMatch::PLAYER_SLOTS.to_h do |slot|
      user = rotation_match.public_send(slot[:player_key])
      favorites = user.user_favorite_suits.order(:slot).pluck(:mobile_suit_id)
      suit_id = favorites.any? && random.rand < 0.7 ? favorites.sample(random: random) : all_suit_ids.sample(random: random)
      [ slot[:player_key], suit_id ]
    end
  end

  def all_suit_ids
    @all_suit_ids ||= MobileSuit.order(:id).ids
  end

  # 実際の試合に近い値で詳細統計を入れる（勝敗・撃墜数・被撃墜数が食い違わないようにする）
  def fill_stats(match)
    players = match.match_players.order(:position).to_a
    winners, losers = players.partition { |player| player.team_number == match.winning_team }
    game_end_cs = random.rand(8_000..18_000)

    loser_deaths = [ [ 1, 1 ], [ 2, 1 ], [ 1, 2 ], [ 2, 0 ], [ 0, 2 ] ].sample(random: random)
    winner_deaths = [ [ 0, 0 ], [ 1, 0 ], [ 0, 1 ], [ 1, 1 ] ].sample(random: random)
    deaths = losers.zip(loser_deaths).to_h.merge(winners.zip(winner_deaths).to_h)
    kills = distribute(loser_deaths.sum, winners).merge(distribute(winner_deaths.sum, losers))
    last_dead = losers.select { |player| deaths[player].positive? }.sample(random: random)

    players.each do |player|
      damage_dealt = random.rand(300..800) + kills[player] * random.rand(150..350)
      exburst_count = random.rand(0..2)
      player.update!(
        score: [ damage_dealt * 18 + kills[player] * 2_000 - deaths[player] * 1_500 + random.rand(0..3_000), 4_000 ].max,
        kills: kills[player],
        deaths: deaths[player],
        damage_dealt: damage_dealt,
        damage_received: random.rand(300..700) + deaths[player] * random.rand(200..400),
        exburst_count: exburst_count,
        exburst_damage: exburst_count.zero? ? 0 : random.rand(50..300) * exburst_count,
        exburst_deaths: random.rand(0..[ exburst_count, deaths[player] ].min),
        first_unit_exburst_count: exburst_count.positive? && random.rand < 0.3 ? 1 : 0,
        last_death_ex_available: player == last_dead ? random.rand < 0.2 : nil,
        survive_loss_ex_available: player == last_dead ? nil : random.rand < 0.2,
        survival_times: survival_times(deaths[player], game_end_cs, alive_at_end: player != last_dead)
      )
    end

    ranked = players.sort_by { |player| -player.score }
    ranked.each_with_index { |player, index| player.update!(match_rank: index + 1) }
    match.update!(team1_ex_overlimit_before_end: random.rand < 0.3, team2_ex_overlimit_before_end: random.rand < 0.3)
  end

  def distribute(total, players)
    counts = players.to_h { |player| [ player, 0 ] }
    total.times { counts[players.sample(random: random)] += 1 }
    counts
  end

  # 1 機ごとの生存時間（センチ秒）。最後に撃墜された機体は試合終了時の生存時間を持たない
  def survival_times(death_count, game_end_cs, alive_at_end:)
    death_times = Array.new(death_count) { random.rand(1_000...game_end_cs) }.sort
    times = ([ 0 ] + death_times).each_cons(2).map { |from, to| to - from }
    alive_at_end ? times + [ game_end_cs - (death_times.last || 0) ] : times
  end

  def create_reactions_and_favorites(users)
    emojis = MasterEmoji.order(:position).to_a
    Match.order(:id).each do |match|
      next unless random.rand < 0.3

      users.sample(random.rand(1..3), random: random).each do |user|
        match.reactions.create!(user: user, master_emoji: emojis.sample(random: random)) if emojis.any?
        user.favorite_matches.create!(match: match) if random.rand < 0.2
      end
    end
  end

  def create_announcement
    Announcement.create!(
      title: "サンプルのお知らせ",
      body: "ローカル確認用のサンプルデータです。\n\n- ログイン: `sample_a` 〜 `sample_f`（パスワード `#{PASSWORD}`）\n- 管理者: `admin`（パスワード `password`）",
      is_active: true,
      published_at: Time.current
    )
  end

  # default の Webhook を全部の投稿先に使い、投稿先ごとに書いたものを優先する
  def create_discord_channels
    webhooks = discord_config["webhooks"] || {}
    unknown = webhooks.keys - DiscordChannel::PURPOSES - [ DISCORD_DEFAULT_KEY ]
    warn "#{discord_config_path.basename}: 知らない投稿先は無視しました（#{unknown.join(', ')}）" if unknown.any?

    DiscordChannel::PURPOSES.each do |purpose|
      url = webhooks[purpose].presence || webhooks[DISCORD_DEFAULT_KEY].presence
      DiscordChannel.create!(purpose: purpose, webhook_url: url, label: "テスト用（#{discord_config_path.basename}）") if url
    end
  end

  def discord_config
    @discord_config ||= File.exist?(discord_config_path) ? YAML.safe_load_file(discord_config_path) || {} : {}
  end
end
