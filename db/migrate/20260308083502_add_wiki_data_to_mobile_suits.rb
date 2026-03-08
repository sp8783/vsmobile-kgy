class AddWikiDataToMobileSuits < ActiveRecord::Migration[8.1]
  def change
    add_column :mobile_suits, :wiki_url, :string
    add_column :mobile_suits, :image_filename, :string
  end
end
