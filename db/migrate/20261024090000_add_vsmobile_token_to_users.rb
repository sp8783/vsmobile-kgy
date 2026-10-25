class AddVsmobileTokenToUsers < ActiveRecord::Migration[8.1]
  # VS.モバイル連携: ブックマークレットの URL に埋める本人用の鍵と、最後に使った日時。
  # 既存のユーザーにも鍵を入れておく（新しいユーザーは has_secure_token が作る）
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    add_column :users, :vsmobile_token, :string
    add_column :users, :vsmobile_token_used_at, :datetime
    add_index :users, :vsmobile_token, unique: true

    MigrationUser.reset_column_information
    MigrationUser.where(vsmobile_token: nil).find_each { |user| user.update_columns(vsmobile_token: SecureRandom.base58(32)) }
  end

  def down
    remove_index :users, :vsmobile_token
    remove_column :users, :vsmobile_token_used_at
    remove_column :users, :vsmobile_token
  end
end
