module Vsmobile
  # イベントの各試合の統計がどこまで届いたか、足りない試合を誰が送れば埋まるか。
  # 試合ごとに、出た 4 人のうち 1 人分のデータが届けばその試合は埋まる
  class Coverage
    Candidate = Data.define(:user, :match_numbers)

    attr_reader :event

    def initialize(event:)
      @event = event
    end

    def matches
      @matches ||= event.matches.includes(:match_timeline, stats_payload: :submitted_by, match_players: :user).order(:played_at, :id).to_a
    end

    def total
      matches.size
    end

    def number_of(match)
      matches.index { |candidate| candidate.id == match.id }&.+(1)
    end

    def covered?(match)
      match.match_timeline.present?
    end

    def covered_count
      matches.count { |match| covered?(match) }
    end

    def complete?
      total.positive? && covered_count == total
    end

    # 取り込めなかった送信（解析・対応づけの失敗の記録）。新しいものから
    def failures
      @failures ||= VsmobileParseFailure.where(event: event).includes(:user).order(updated_at: :desc).to_a
    end

    def failure_senders
      failures.map(&:sender_name).uniq
    end

    # 足りない試合の番号
    def missing_numbers
      matches.each_with_index.reject { |match, _| covered?(match) }.map { |_, index| index + 1 }
    end

    # 足りない試合に出た人（ゲストを除く）と、その人が送れば埋まる試合の番号。埋まる数の多い順
    def candidates
      @candidates ||= begin
        by_user = Hash.new { |hash, user| hash[user] = [] }
        matches.each_with_index do |match, index|
          next if covered?(match)

          match.match_players.each do |player|
            by_user[player.user] << index + 1 unless player.user.is_guest
          end
        end
        by_user.map { |user, numbers| Candidate.new(user: user, match_numbers: numbers.uniq) }
               .sort_by { |candidate| [ -candidate.match_numbers.size, candidate.user.nickname ] }
      end
    end

    def candidate_for(user)
      candidates.find { |candidate| candidate.user.id == user&.id }
    end

    # 1 人で足りない試合を全部埋められる人
    def single_finishers
      missing = missing_numbers
      candidates.select { |candidate| (missing - candidate.match_numbers).empty? }.map(&:user)
    end

    # 足りない試合に出た人（ゲストを除く）と、その人が送れば埋まる試合の番号。埋まる数の多い順
    def candidates
      @candidates ||= begin
        by_user = Hash.new { |hash, user| hash[user] = [] }
        matches.each_with_index do |match, index|
          next if covered?(match)

          match.match_players.each do |player|
            by_user[player.user] << index + 1 unless player.user.is_guest
          end
        end
        by_user.map { |user, numbers| Candidate.new(user: user, match_numbers: numbers.uniq) }
               .sort_by { |candidate| [ -candidate.match_numbers.size, candidate.user.nickname ] }
      end
    end

    def candidate_for(user)
      candidates.find { |candidate| candidate.user.id == user&.id }
    end

    # 足りない試合を全部埋めるのに最少で何人要るか（nil = 足りない試合がない、または誰が送っても埋まらない）。
    # 画面では「あと N 人」と出す。8 人の対戦会では 1 人送るごとに 1 人減り、誰が送るかで大きくは変わらない（過去のイベントで確認）
    def minimum_people
      missing = missing_numbers
      return nil if missing.empty?

      (1..candidates.size).find do |size|
        candidates.combination(size).any? { |set| (missing - set.flat_map(&:match_numbers)).empty? }
      end
    end

    # イベントに出た人（ゲストを除く）。ニックネーム順
    def participants
      @participants ||= matches.flat_map { |match| match.match_players.map(&:user) }.uniq.reject(&:is_guest).sort_by(&:nickname)
    end

    def participant?(user)
      participants.any? { |participant| participant.id == user&.id }
    end

    # データを送った人（VS.モバイル連携）
    def submitters
      matches.filter_map { |match| match.stats_payload&.submitted_by }.uniq
    end

    def submitted?(user)
      submitters.any? { |submitter| submitter.id == user&.id }
    end

    # まだ送っていない人（管理者が声をかける相手）
    def not_submitted
      participants - submitters
    end

    def bulk_imported?
      matches.any? { |match| match.stats_payload && match.stats_payload.submitted_by.nil? }
    end

    # 試合の統計がどこから来たか: VS.モバイル連携なら「Aさんのデータ」、それ以外（一括取得・手入力・古いデータ）は「取り込み済み」。届いていなければ nil
    def source_label(match)
      return nil unless covered?(match)

      submitter = match.stats_payload&.submitted_by
      submitter ? "#{submitter.nickname}のデータ" : "取り込み済み"
    end
  end
end
