class AddVideoTimestampToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :video_timestamp, :integer
  end
end
