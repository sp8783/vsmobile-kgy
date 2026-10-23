require "test_helper"

class Admin::MatchCsvImporterTest < ActiveSupport::TestCase
  setup do
    MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
  end

  test "CSV にいない名前のユーザーは、仮のパスワードで作る（固定の値ではログインできない）" do
    result = import(<<~CSV)
      日付,勝敗1,プレイヤー1,使用機体1,プレイヤー2,使用機体2,プレイヤー3,使用機体3,プレイヤー4,使用機体4
      2026/10/11,1,Aさん,テスト機体,Bさん,テスト機体,Cさん,テスト機体,Dさん,テスト機体
    CSV

    assert result.success?, result.errors.join(" | ")
    assert_equal 4, result.created_user_count
    assert_equal 1, Match.count
    created = User.where(nickname: %w[Aさん Bさん Cさん Dさん])
    assert_equal 4, created.count
    assert created.none? { |user| user.valid_password?("password") }, "固定のパスワードでログインできてはいけない"
    assert_match "4人のユーザーを作成しました（パスワードは未設定です。ユーザー管理から設定してください）", result.flash[:notice]
  end

  private

  def import(csv)
    Tempfile.create([ "matches", ".csv" ]) do |file|
      file.write(csv)
      file.flush
      Admin::MatchCsvImporter.new(file: file).call
    end
  end
end
