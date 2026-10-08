class AddWikiPageIdToMobileSuits < ActiveRecord::Migration[8.1]
  def up
    add_column :mobile_suits, :wiki_page_id, :integer

    # 機体を名前ではなく Wiki のページ ID で突き合わせるため、既存データは wiki_url から埋める
    execute <<~SQL
      UPDATE mobile_suits
      SET wiki_page_id = substring(wiki_url from 'pages/([0-9]+)\\.html')::integer
      WHERE wiki_url ~ 'pages/[0-9]+\\.html'
    SQL

    add_index :mobile_suits, :wiki_page_id, unique: true
  end

  def down
    remove_index :mobile_suits, :wiki_page_id
    remove_column :mobile_suits, :wiki_page_id
  end
end
