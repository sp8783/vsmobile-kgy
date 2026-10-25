require "test_helper"

# 設定画面の「VS.モバイル連携」（ブックマークレットの URL の表示と鍵の作り直し）と、イベントの画面の取得状況
class ProfileVsmobileLinkTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(username: "player_a", nickname: "Aさん", password: "password123")
    sign_in @user
  end

  test "設定に、本人用の鍵を埋めたブックマークの URL と使い方へのリンクを出す（手順は載せない）" do
    get edit_profile_path

    assert_response :success
    assert_select "section#vsmobile h2", text: "VS.モバイル連携"
    assert_select "section#vsmobile a[href=?]", vsmobile_guide_path, text: "使い方 →"
    assert_select "textarea#vsmobile-bookmarklet", text: %r{\Ajavascript:\(function\(\)\{.*http://www\.example\.com/vsm/collect\.js\?k=#{@user.vsmobile_token}&t='\+Date\.now\(\).*\}\)\(\)\z}
    assert_select "button.vl-copy-btn", text: /コピー/
    assert_select "form[action=?] button", vsmobile_token_path, text: "作り直す"
    assert_select "section#vsmobile .vl-caution", text: /あなた専用です/
    assert_select "section#vsmobile .vl-steps", 0
  end

  test "使い方のページは、ログインしていなくても見られる" do
    sign_out @user

    get vsmobile_guide_path

    assert_response :success
    assert_select "h1", text: "VS.モバイル連携の使い方"
    assert_select "h2.vl-h2", text: "準備（最初に 1 回だけ）"
    assert_select "h2.vl-h2", text: "対戦会のあと（毎回）"
    assert_select "h2.vl-h2", text: "うまくいかないとき"
    assert_select ".vl-steps li", 5
    assert_select ".vl-bookmark dd", text: "自由（例: KGY 戦績送信）"
    assert_select ".vl-faq li", 3
    assert_select ".vl-steps a[href=?]", new_user_session_path, text: "設定を開く →"

    sign_in @user
    get vsmobile_guide_path
    assert_select ".vl-steps a[href=?]", edit_profile_path(anchor: "vsmobile"), text: "設定を開く →"
  end

  test "鍵を作り直すと古い URL は使えなくなる" do
    old_token = @user.vsmobile_token
    @user.update!(vsmobile_token_used_at: Time.current)

    post vsmobile_token_path

    assert_redirected_to edit_profile_path(anchor: "vsmobile")
    assert_match "作り直しました", flash[:notice]
    @user.reload
    assert_not_equal old_token, @user.vsmobile_token
    assert_nil @user.vsmobile_token_used_at
    get "/api/vsmobile/targets", headers: { "Authorization" => "Bearer #{old_token}" }
    assert_response :unauthorized
  end

  test "鍵がまだない人には「連携 URL を作る」を出し、押すと作られる" do
    @user.update_column(:vsmobile_token, nil)

    get edit_profile_path
    assert_select "form[action=?] button", vsmobile_token_path, text: "連携 URL を作る"
    assert_select "textarea#vsmobile-bookmarklet", 0

    post vsmobile_token_path
    assert_match "作りました", flash[:notice]
    assert @user.reload.vsmobile_token.present?
  end

  test "ゲストは鍵を作れない" do
    sign_in User.create!(username: "guest", nickname: "ゲスト", password: "password123", is_guest: true)

    post vsmobile_token_path

    assert_redirected_to root_path
  end

  test "イベントの画面で、送れば埋まる試合がある人には呼びかけを出す" do
    event, others = build_event_with_match

    get event_path(event)

    assert_response :success
    assert_select ".vc-cta-title", text: "対戦結果の送信をお願いします"
    assert_select ".vc-cta-body", text: /\Aあなたの 1 試合分が、まだ登録されていません。\s*VS.モバイルを開いて、連携のブックマークを開いてください。\z/
    assert_select ".vc-cta a[href=?]", vsmobile_guide_path, text: "送り方を見る →"
    assert_select ".vc-cta-foot", text: /統計の登録状況 0 \/ 1 試合/
    assert_select ".vc-people", 0, "一般の人には誰が送ったかの一覧は出さない"

    # 2 試合中 1 試合だけ自分が出ているとき: 「すべてそろう」とは書かない
    event.matches.create!(played_at: Time.current + 5.minutes, winning_team: 1,
                          match_players_attributes: players_for(%w[E F G H].map { |n| User.create!(username: "u_#{n}", nickname: "#{n}さん", password: "password123") }))
    get event_path(event)
    assert_select ".vc-cta-body", text: /あなたの 1 試合分が、まだ登録されていません。/
  end

  test "イベントの画面で、自分の分が届いていて送っても増えない人には届いたことだけを出す" do
    event, others = build_event_with_match
    event.matches.first.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] })
    event.matches.first.create_stats_payload!(payload: { "match_ts" => 1 }, submitted_by: others["Bさん"], submitted_at: Time.current)
    event.matches.create!(played_at: Time.current + 5.minutes, winning_team: 1,
                          match_players_attributes: players_for(%w[E F G H].map { |n| User.create!(username: "u_#{n}", nickname: "#{n}さん", password: "password123") }))

    get event_path(event)

    assert_select ".vc-cta", 0
    assert_select ".vc-thanks", text: /あなたの対戦結果は登録済みです。.*統計の登録状況 1 \/ 2 試合/m
  end

  test "管理者には、送った人とまだの人の一覧を出す（送り方のリンクはなし）" do
    admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    sign_in admin
    event, others = build_event_with_match
    second = event.matches.create!(played_at: Time.current + 5.minutes, winning_team: 2,
                                   match_players_attributes: players_for([ @user, others["Bさん"], others["Cさん"], others["Dさん"] ]))
    second.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] })
    second.create_stats_payload!(payload: { "match_ts" => 1 }, submitted_by: others["Bさん"], submitted_at: Time.current)

    get event_path(event)

    assert_select ".vc-panel h2", text: "各試合の統計"
    assert_select ".vc-people li", 4
    assert_select ".vc-people li:first-child", text: /Bさん\s*送信済み/
    assert_select ".vc-people li", text: /Aさん\s*送ると 1 試合（全部そろう）/
    assert_select ".vc-cta", 0
    assert_select ".vc-fail", 0

    VsmobileParseFailure.create!(user: others["Cさん"], event: event, match_ts: 1, error_message: "試合のメンバーが見つかりません", html: "<p>x</p>")
    VsmobileParseFailure.create!(user: others["Cさん"], event: event, match_ts: 2, error_message: "試合のメンバーが見つかりません", html: "<p>x</p>")
    VsmobileParseFailure.create!(user: nil, event: event, match_ts: 3, error_message: "試合がイベントに見つかりません", html: "<p>x</p>")
    get event_path(event)
    assert_select ".vc-fail", text: /取り込めなかった送信: 3 件（退会した人・Cさん）\s*最新のエラー: 試合がイベントに見つかりません/
    assert_select "a[href=?]", edit_profile_path(anchor: "vsmobile"), 0
  end

  test "管理者が視点を切り替えているときは、その人への呼びかけになる" do
    admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    sign_in admin
    event, _others = build_event_with_match
    post switch_view_admin_user_path(@user)

    get event_path(event)

    assert_select ".vc-cta-title", text: "対戦結果の送信をお願いします"
    assert_select ".vc-people", 0
  end

  test "ダッシュボードにも、対戦結果がまだ届いていないイベントの呼びかけを出す" do
    event, _others = build_event_with_match

    get dashboard_path

    assert_response :success
    assert_select ".vc-cta-title", text: "対戦結果の送信をお願いします"
    assert_select ".vc-cta-body a[href=?]", event_path(event), text: "第6回 対戦会"
    assert_select ".vc-cta-body", text: /第6回 対戦会のあなたの 1 試合分が、まだ登録されていません/

    event.matches.first.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] })
    get dashboard_path
    assert_select ".vc-cta", 0
    assert_select ".vc-thanks", 0, "ダッシュボードには届いたことは出さない"
  end

  test "全試合そろっているイベントや 30 日より前のイベントでは何も出さない" do
    event, _others = build_event_with_match(held_on: 40.days.ago.to_date, played_at: 40.days.ago)

    get event_path(event)
    assert_select ".vc-cta", 0
    assert_select ".vc-panel", 0

    event.update!(held_on: Date.current)
    event.matches.first.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] })
    get event_path(event)
    assert_select ".vc-cta", 0
    assert_select ".vc-thanks", 0
    assert_select ".vc-panel", 0
  end

  private

  # 自分と B・C・D さんの 1 試合だけのイベント
  def build_event_with_match(held_on: Date.current, played_at: Time.current)
    event = Event.create!(name: "第6回 対戦会", held_on: held_on)
    others = %w[Bさん Cさん Dさん].index_with { |name| User.find_by(nickname: name) || User.create!(username: "u_#{name.hash.abs}", nickname: name, password: "password123") }
    event.matches.create!(played_at: played_at, winning_team: 1, match_players_attributes: players_for([ @user, others["Bさん"], others["Cさん"], others["Dさん"] ]))
    [ event, others ]
  end

  def players_for(users)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    users.each_with_index.map { |user, i| { user: user, mobile_suit: suit, team_number: i < 2 ? 1 : 2, position: i + 1 } }
  end
end
