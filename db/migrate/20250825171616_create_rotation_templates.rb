class CreateRotationTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :rotation_templates do |t|
      t.string :name
      t.integer :player_count
      t.integer :match_count

      t.timestamps
    end
  end
end
