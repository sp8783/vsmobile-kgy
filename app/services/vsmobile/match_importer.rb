module Vsmobile
  # 届いた 1 試合分の統計データ（scrape.py の出力と同じ形。match_ts・team_a・team_b・timeline_raw）を、
  # イベントのどの試合のものかを決めて取り込む。一括取得（GitHub Actions）と VS.モバイル連携（ブックマークレット）の両方がここを通る
  #
  # - 同じ開始時刻（match_ts）の試合が既にあれば、先に届いた方を正として触らない
  # - 試合は「同じ 4 人・同じチーム分け」でイベント内の試合を集め、開始時刻の順と登録順の k 番目どうしを対応づける。
  #   送った人はそのグループの試合に全部出ているので、誰が送っても同じ対応になる（開始時刻の昇順で送ることが前提）
  class MatchImporter
    class NoMatchError < StandardError; end

    Result = Data.define(:status, :match) # status: :imported / :already

    def initialize(event:, parsed:, submitted_by: nil)
      @event = event
      @parsed = parsed
      @submitted_by = submitted_by
    end

    def import!
      match_ts = Integer(parsed["match_ts"], exception: false)
      raise NoMatchError, "試合の開始時刻（match_ts）がありません" unless match_ts

      started_at = Time.zone.at(match_ts)
      # 同じイベントへの取り込みは 1 件ずつ（2 人が同じ試合を同時に送っても二重に取り込まない）
      event.with_lock do
        if (existing = event.matches.find_by(game_started_at: started_at))
          return Result.new(status: :already, match: existing)
        end

        match = target_match(started_at)
        MatchTimelineImporter.new(match: match, parsed: parsed).apply!
        match.stats_payload.update!(submitted_by: submitted_by, submitted_at: Time.current)
        Result.new(status: :imported, match: match)
      end
    end

    private

    attr_reader :event, :parsed, :submitted_by

    def team_names(team)
      parsed.dig(team, "players")&.map { |player| player["name"].presence }&.compact.presence
    end

    def target_match(started_at)
      team_a = team_names("team_a")
      team_b = team_names("team_b")
      raise NoMatchError, "試合の 4 人の名前が読み取れませんでした" unless team_a && team_b

      group = event.matches.includes(match_players: :user).order(:played_at, :id).select { |match| same_card?(match, team_a, team_b) }
      if group.empty?
        raise NoMatchError, "#{(team_a + team_b).join('・')} の試合がイベントに見つかりません（ニックネームが VS.モバイルの名前と違うか、試合が登録されていません）"
      end

      index = group.count { |match| match.game_started_at && match.game_started_at < started_at }
      candidate = group.drop(index).find { |match| match.game_started_at.nil? }
      raise NoMatchError, "#{(team_a + team_b).join('・')} の試合はすべて取り込み済みです" unless candidate

      candidate
    end

    def same_card?(match, team_a, team_b)
      team1 = nicknames(match, 1)
      team2 = nicknames(match, 2)
      (team1 == team_a.sort && team2 == team_b.sort) || (team1 == team_b.sort && team2 == team_a.sort)
    end

    def nicknames(match, team_number)
      match.match_players.select { |player| player.team_number == team_number }.map { |player| player.user.nickname }.sort
    end
  end
end
