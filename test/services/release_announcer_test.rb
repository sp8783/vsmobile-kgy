require "test_helper"

class ReleaseAnnouncerTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @posted = []
    @post_result = true
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "未告知のバージョンはお知らせを公開し、Discord に投稿する" do
    write_note("v2.4.0", discord: "@everyone v2.4.0 リリース！")

    result = announcer.call.sole

    assert result.announced
    assert result.discord_posted
    announcement = ReleaseAnnouncement.find_by!(version: "v2.4.0").announcement
    assert_equal [ "v2.4.0 リリース！", true ], [ announcement.title, announcement.is_active ]
    assert_equal [ "@everyone v2.4.0 リリース！" ], @posted
  end

  test "告知済みのバージョンは何もしない" do
    write_note("v2.4.0", discord: "告知")
    announcer.call

    result = announcer.call.sole

    assert_not result.announced
    assert_not result.discord_posted
    assert_equal 1, Announcement.count
    assert_equal 1, @posted.size
  end

  test "Discord への投稿に失敗したら、次回の起動時に再送する" do
    write_note("v2.4.0", discord: "告知")
    @post_result = false
    announcer.call

    @post_result = true
    result = announcer.call.sole

    assert result.discord_posted
    assert_equal 1, Announcement.count
    assert ReleaseAnnouncement.find_by!(version: "v2.4.0").discord_posted_at
  end

  test "告知を作ってから 3 日を過ぎたら Discord には再送しない" do
    write_note("v2.4.0", discord: "告知")
    @post_result = false
    announcer.call
    ReleaseAnnouncement.find_by!(version: "v2.4.0").update!(created_at: 4.days.ago)

    @post_result = true
    result = announcer.call.sole

    assert_not result.discord_posted
  end

  test "Discord の本文がなければアプリ内お知らせだけを出す" do
    write_note("v2.3.2", discord: nil)

    result = announcer.call.sole

    assert result.announced
    assert_not result.discord_posted
    assert_empty @posted
  end

  test "バージョン順に告知する" do
    write_note("v2.10.0", discord: "b")
    write_note("v2.9.1", discord: "a")

    assert_equal %w[v2.9.1 v2.10.0], announcer.call.map(&:version)
  end

  private

  def announcer
    ReleaseAnnouncer.new(dir: @dir, poster: ->(message) { @posted << message; @post_result })
  end

  def write_note(version, discord:)
    data = { "title" => "#{version} リリース！", "body" => "## 変更点\n- いろいろ" }
    data["discord"] = discord if discord
    File.write(File.join(@dir, "#{version}.yml"), data.to_yaml)
  end
end
