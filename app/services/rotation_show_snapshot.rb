class RotationShowSnapshot
  def initialize(rotation:, show_completion_modal:, target_index: nil)
    @rotation = rotation
    @show_completion_modal = show_completion_modal
    @target_index = target_index
  end

  def to_h
    preload_form_match_favorites

    {
      rotation_matches: rotation_matches,
      current_match: current_match,
      form_match: form_match,
      form_mode: form_mode,
      pending_matches: pending_matches,
      has_next_match: rotation.next_upcoming_match_index.present?,
      player_statistics: rotation.player_statistics(rotation_matches),
      all_mobile_suits: MobileSuit.order(:name).to_a,
      show_completion_modal: show_completion_modal
    }
  end

  private

  attr_reader :rotation, :show_completion_modal, :target_index

  def rotation_matches
    @rotation_matches ||= rotation.rotation_matches
                                 .includes(
                                   :team1_player1,
                                   :team1_player2,
                                   :team2_player1,
                                   :team2_player2,
                                   match: { match_players: :mobile_suit }
                                 )
                                 .order(:match_index)
                                 .to_a
  end

  def current_match
    @current_match ||= rotation_matches[rotation.current_match_index]
  end

  def pending_matches
    @pending_matches ||= rotation_matches.select { |rotation_match| status_of(rotation_match) == :pending }
  end

  # 入力フォームの対象。?target= で未入力・入力済みの試合を指定でき、なければ結果のない現在の試合
  def form_match
    return @form_match if defined?(@form_match)

    target = target_index && rotation_matches[target_index]
    @form_match =
      if target && %i[pending recorded].include?(status_of(target))
        target
      elsif current_match && status_of(current_match) == :current
        current_match
      end
  end

  # :current（現在の試合を入力して進む）/ :pending（未入力の試合を入力）/ :edit（入力済みを編集）
  def form_mode
    return unless form_match

    case status_of(form_match)
    when :current then :current
    when :pending then :pending
    when :recorded then :edit
    end
  end

  def status_of(rotation_match)
    rotation_match.progress_status(rotation.current_match_index)
  end

  def preload_form_match_favorites
    return unless form_match

    ActiveRecord::Associations::Preloader.new(
      records: form_match.players,
      associations: :user_favorite_suits
    ).call
  end
end
