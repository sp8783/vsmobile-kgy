class ConvertUtcPlayedAtToJst < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE matches m
      SET played_at = m.played_at + INTERVAL '9 hours'
      FROM events e
      WHERE m.event_id = e.id
      AND DATE(m.played_at) = e.held_on - INTERVAL '1 day'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE matches m
      SET played_at = m.played_at - INTERVAL '9 hours'
      FROM events e
      WHERE m.event_id = e.id
      AND DATE(m.played_at) != e.held_on
    SQL
  end
end
