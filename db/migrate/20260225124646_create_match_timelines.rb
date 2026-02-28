class CreateMatchTimelines < ActiveRecord::Migration[8.1]
  def change
    create_table :match_timelines do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.jsonb    :timeline_raw, null: false
      t.integer  :game_end_cs
      t.string   :game_end_str

      t.timestamps
    end
  end
end
