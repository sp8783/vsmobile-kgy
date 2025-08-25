class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name
      t.date :date
      t.datetime :start_time
      t.datetime :end_time
      t.string :event_type
      t.string :location
      t.text :notes

      t.timestamps
    end
  end
end
