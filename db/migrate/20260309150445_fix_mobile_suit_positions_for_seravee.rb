class FixMobileSuitPositionsForSeravee < ActiveRecord::Migration[8.1]
  def up
    # セラヴィーガンダム（id=247）は position=101 が正しい位置。
    # しかし既存のラファエルガンダム以降も position=101 から始まっており重複している。
    # seeds.rb の定義通り、セラヴィーガンダム以外の position >= 101 を +1 シフトする。
    execute <<~SQL
      UPDATE mobile_suits
      SET position = position + 1
      WHERE position >= 101 AND id != 247
    SQL
  end

  def down
    execute <<~SQL
      UPDATE mobile_suits
      SET position = position - 1
      WHERE position >= 102 AND id != 247
    SQL
  end
end
