class CreateMasterEmojis < ActiveRecord::Migration[8.1]
  def change
    create_table :master_emojis do |t|
      t.string :name, null: false
      t.string :image_key, null: false
      t.integer :position
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
  end
end
