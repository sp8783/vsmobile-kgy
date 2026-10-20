require "test_helper"

# config/release_notes の告知文ファイルが、起動時の告知処理で読める形になっているかを確認する
class ReleaseNotesTest < ActiveSupport::TestCase
  ReleaseAnnouncer.load_notes.each do |note|
    test "#{note.version}: タイトル・本文があり、Discord の本文は投稿できる長さ" do
      assert_match(/\Av\d+\.\d+\.\d+\z/, note.version)
      assert note.title.present?
      assert note.body.present?
      assert_operator note.discord.to_s.length, :<=, ReleaseAnnouncer::DISCORD_LIMIT
    end
  end
end
