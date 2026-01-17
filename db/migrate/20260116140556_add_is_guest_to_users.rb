class AddIsGuestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_guest, :boolean, default: false, null: false

    # Set existing guest user (username: 'guest') to is_guest: true
    reversible do |dir|
      dir.up do
        User.where(username: 'guest').update_all(is_guest: true)
      end
    end
  end
end
