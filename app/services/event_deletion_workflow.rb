class EventDeletionWorkflow
  Result = Struct.new(:success?, :event_name, :error_message, keyword_init: true)

  def initialize(event:)
    @event = event
  end

  def call
    event_name = event.name

    ActiveRecord::Base.transaction do
      unlink_rotation_matches!
      event.destroy!
    end

    Result.new(success?: true, event_name: event_name)
  rescue StandardError => error
    Result.new(success?: false, event_name: event.name, error_message: error.message)
  end

  private

  attr_reader :event

  def unlink_rotation_matches!
    match_ids = event.matches.pluck(:id)
    return if match_ids.empty?

    RotationMatch.where(match_id: match_ids).update_all(match_id: nil)
  end
end
