class MatchDeletionWorkflow
  Result = Struct.new(:success?, :deleted_count, :event, :rotation, :error_message, keyword_init: true)

  def initialize(matches:)
    @matches = Array(matches).flatten.compact
  end

  def call
    deleted_count = 0

    ActiveRecord::Base.transaction do
      unlink_rotation_matches!
      deleted_count = destroy_matches!
      affected_rotations.each(&:sync_current_match_index!)
    end

    Result.new(
      success?: true,
      deleted_count: deleted_count,
      event: primary_match&.event,
      rotation: primary_rotation
    )
  rescue StandardError => error
    Result.new(
      success?: false,
      deleted_count: 0,
      event: primary_match&.event,
      rotation: primary_rotation,
      error_message: error.message
    )
  end

  private

  attr_reader :matches

  def primary_match
    @primary_match ||= matches.one? ? matches.first : nil
  end

  def primary_rotation
    @primary_rotation ||= primary_match && rotation_by_match_id[primary_match.id]
  end

  def affected_rotations
    @affected_rotations ||= rotation_by_match_id.values.compact.uniq
  end

  def rotation_by_match_id
    @rotation_by_match_id ||= begin
      RotationMatch.where(match_id: match_ids).includes(:rotation).each_with_object({}) do |rotation_match, mapping|
        mapping[rotation_match.match_id] = rotation_match.rotation
      end
    end
  end

  def match_ids
    @match_ids ||= matches.map(&:id)
  end

  def unlink_rotation_matches!
    return if match_ids.empty?

    RotationMatch.where(match_id: match_ids).update_all(match_id: nil)
  end

  def destroy_matches!
    matches.count do |match|
      match.destroy!
      true
    end
  end
end
