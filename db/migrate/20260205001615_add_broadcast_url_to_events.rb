class AddBroadcastUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :broadcast_url, :string
  end
end
