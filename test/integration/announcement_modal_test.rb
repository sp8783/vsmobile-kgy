require "test_helper"

# お知らせのモーダル。未読が複数あっても 1 つにまとめて出し、「閉じる」でまとめて既読にする
class AnnouncementModalTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(username: "player_a", nickname: "Aさん", password: "password123")
    @older = Announcement.create!(title: "🚀 v2.5.0 アップデートのお知らせ", body: "古い方", published_at: 2.days.ago, is_active: true)
    @newer = Announcement.create!(title: "🚀 v2.6.0 アップデートのお知らせ", body: "新しい方", published_at: 1.day.ago, is_active: true)
    sign_in @user
  end

  test "未読が複数あれば 1 つのモーダルにまとめて新しい順に出し、閉じるとすべて既読になって出なくなる" do
    get root_path

    assert_select "#announcement-modal", 1
    assert_select "#announcement-modal h2", text: "お知らせが 2 件あります"
    assert_select "#announcement-modal h3", 2
    assert_select "#announcement-modal h3:first-of-type span", text: "🚀 v2.6.0 アップデートのお知らせ"
    assert_select "#announcement-modal h3 time", 2
    assert_select "#announcement-modal form[action=?]", mark_all_as_read_announcements_path

    post mark_all_as_read_announcements_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match 'action="remove" target="announcement-modal"', response.body
    assert_equal [ @older.id, @newer.id ].sort, @user.user_announcement_reads.pluck(:announcement_id).sort
    get events_path
    assert_select "#announcement-modal", 0
  end

  test "未読が 1 件ならタイトルを見出しにしてそのまま出す" do
    @user.user_announcement_reads.create!(announcement: @older)

    get root_path

    assert_select "#announcement-modal h2", text: "🚀 v2.6.0 アップデートのお知らせ"
    assert_select "#announcement-modal h3", 0
  end

  test "公開前・期限切れ・無効のお知らせは出さない" do
    @user.user_announcement_reads.create!(announcement: @older)
    @newer.update!(is_active: false)
    Announcement.create!(title: "予約", body: "まだ", published_at: 1.day.from_now, is_active: true)
    Announcement.create!(title: "期限切れ", body: "もう", published_at: 3.days.ago, expires_at: 1.day.ago, is_active: true)

    get root_path

    assert_select "#announcement-modal", 0
  end
end
