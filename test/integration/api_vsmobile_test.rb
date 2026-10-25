require "test_helper"

# VS.モバイル連携の API（web.vsmobile.jp 上のブックマークレットから、本人用の鍵で送る）
class ApiVsmobileTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  MATCH_TS = Time.zone.local(2026, 11, 7, 10, 12, 5).to_i

  setup do
    @event = Event.create!(name: "第6回 対戦会", held_on: Date.new(2026, 11, 7))
    @users = %w[Aさん Bさん Cさん Dさん Eさん].index_with { |name| User.create!(username: "u_#{name.hash.abs}", nickname: name, password: "password123") }
    @match = create_match(%w[Aさん Bさん], %w[Cさん Dさん])
    @other = create_match(%w[Aさん Eさん], %w[Bさん Cさん])
    @html = file_fixture("vsmobile_match_detail.html").read
    travel_to Time.zone.local(2026, 11, 8, 9, 0)
  end

  teardown { travel_back }

  test "対象: 直近 30 日に自分が出たイベントと、届いている試合の開始時刻を返し、鍵の使用日時を記録する" do
    @other.update!(game_started_at: Time.zone.at(MATCH_TS + 600))

    get "/api/vsmobile/targets", headers: headers_for(@users["Aさん"])

    assert_response :success
    body = response.parsed_body
    assert_equal "Aさん", body["user"]["nickname"]
    event = body["events"].sole
    assert_equal @event.id, event["id"]
    assert_equal "2026-11-07", event["held_on"]
    assert_equal 2, event["total"]
    assert_equal [ MATCH_TS + 600 ], event["covered_match_ts"]
    assert_not event["complete"]
    assert_match %r{/events/#{@event.id}\z}, event["url"]
    assert_in_delta Time.current, @users["Aさん"].reload.vsmobile_token_used_at, 1.second
  end

  test "対象: 出ていないイベントや 30 日より前のイベントは返さない" do
    Event.create!(name: "昔の対戦会", held_on: Date.new(2026, 9, 1))

    get "/api/vsmobile/targets", headers: headers_for(@users["Eさん"])

    assert_equal [ @event.id ], response.parsed_body["events"].map { |event| event["id"] }
    get "/api/vsmobile/targets", headers: headers_for(User.create!(username: "nobody", nickname: "出てない人", password: "password123"))
    assert_equal [], response.parsed_body["events"]
  end

  test "鍵がない・違う・ゲストの鍵なら 401" do
    get "/api/vsmobile/targets"
    assert_response :unauthorized

    get "/api/vsmobile/targets", headers: { "Authorization" => "Bearer wrong" }
    assert_response :unauthorized
    assert_match "連携 URL が無効", response.parsed_body["error"]

    guest = User.create!(username: "guest", nickname: "ゲスト", password: "password123", is_guest: true)
    get "/api/vsmobile/targets", headers: headers_for(guest)
    assert_response :unauthorized
  end

  test "試合ページの HTML を解析して取り込み、送った人を記録し、取得状況を返す" do
    post "/api/vsmobile/matches", params: match_params(self_name: "Bさん").to_json, headers: headers_for(@users["Bさん"])

    assert_response :success
    assert_equal({ "status" => "imported", "match_number" => 1, "covered" => 1, "total" => 2, "remaining" => 1 }, response.parsed_body)
    @match.reload
    assert_equal Time.zone.at(MATCH_TS), @match.game_started_at
    assert_equal 1500, @match.match_players.find_by(user: @users["Bさん"]).score
    assert_equal 1, @match.match_players.find_by(user: @users["Bさん"]).match_rank
    assert_equal @users["Bさん"], @match.stats_payload.submitted_by
    assert_equal "2026/11/07(土)", @match.stats_payload.payload["game_date"]
    assert_equal "win", @match.stats_payload.payload["team_a"]["result"]
    assert_equal 15015, @match.match_timeline.game_end_cs
  end

  test "同じ試合が 2 人から届いたら、あとの方は already" do
    post "/api/vsmobile/matches", params: match_params(self_name: "Bさん").to_json, headers: headers_for(@users["Bさん"])
    post "/api/vsmobile/matches", params: match_params(self_name: "Cさん", result_self: "lose").to_json, headers: headers_for(@users["Cさん"])

    assert_response :success
    assert_equal "already", response.parsed_body["status"]
    assert_equal @users["Bさん"], @match.reload.stats_payload.submitted_by
  end

  test "送った人が試合の 4 人にいなければ 422" do
    post "/api/vsmobile/matches", params: match_params(self_name: "Eさん").to_json, headers: headers_for(@users["Eさん"])

    assert_response :unprocessable_entity
    assert_match "あなたのニックネーム「Eさん」がありません", response.parsed_body["error"]
    assert_nil @match.reload.game_started_at
    failure = VsmobileParseFailure.sole
    assert_equal [ @users["Eさん"], @event, MATCH_TS ], [ failure.user, failure.event, failure.match_ts ]
    assert_match "ニックネーム「Eさん」がありません", failure.error_message
    assert_equal({ "result_self" => "win", "self_name" => "Eさん", "time" => "10:12", "game_date" => "2026/11/07(土)", "shop_name" => "テスト店" }, failure.request_params)
    assert_equal @html, failure.html
  end

  test "解析できないページや、イベントにない試合は 422 で理由を返す" do
    post "/api/vsmobile/matches", params: match_params(match_ts: MATCH_TS + 1).merge(html: "<html><body>ログイン</body></html>").to_json, headers: headers_for(@users["Bさん"])
    assert_response :unprocessable_entity
    assert_match "メンバーが見つかりません", response.parsed_body["error"]

    @match.destroy!
    post "/api/vsmobile/matches", params: match_params.to_json, headers: headers_for(@users["Bさん"])
    assert_response :unprocessable_entity
    assert_match "試合がイベントに見つかりません", response.parsed_body["error"]

    post "/api/vsmobile/matches", params: match_params.merge(event_id: 0).to_json, headers: headers_for(@users["Bさん"])
    assert_response :not_found

    # 解析できなかった・試合がなかった、の 2 件が HTML ごと残る（イベントがないものは HTML を見ていないので残さない）
    assert_equal [ "試合のメンバーが見つかりません", "Aさん・Bさん・Cさん・Dさん の試合がイベントに見つかりません" ], VsmobileParseFailure.order(:id).map { |f| f.error_message[/\A[^（。]+/] }
    assert_equal [ "<html><body>ログイン</body></html>", @html ], VsmobileParseFailure.order(:id).map(&:html)
  end

  test "取り込めなかった送信の記録は、同じ人・同じ試合なら上書きし、30 日より古いものは消す" do
    old = VsmobileParseFailure.create!(user: @users["Bさん"], event: @event, match_ts: 1, error_message: "昔の失敗", html: "<p>old</p>", updated_at: 31.days.ago, created_at: 31.days.ago)
    broken = match_params.merge(html: "<html><body>ログイン</body></html>")

    post "/api/vsmobile/matches", params: broken.to_json, headers: headers_for(@users["Bさん"])
    post "/api/vsmobile/matches", params: broken.merge(html: "<html><body>ログイン 2 回目</body></html>").to_json, headers: headers_for(@users["Bさん"])

    assert_response :unprocessable_entity
    assert_equal 1, VsmobileParseFailure.count
    assert_equal "<html><body>ログイン 2 回目</body></html>", VsmobileParseFailure.sole.html
    assert_not VsmobileParseFailure.exists?(old.id)
  end

  test "記録に失敗しても、元のエラー応答は返す" do
    # 記録の保存を失敗させる（minitest/mock は入っていない）
    VsmobileParseFailure.define_singleton_method(:find_or_initialize_by) { |*, **| raise ActiveRecord::StatementInvalid, "db down" }
    begin
      post "/api/vsmobile/matches", params: match_params.merge(html: "<html><body>ログイン</body></html>").to_json, headers: headers_for(@users["Bさん"])
    ensure
      VsmobileParseFailure.singleton_class.remove_method(:find_or_initialize_by)
    end

    assert_response :unprocessable_entity
    assert_match "メンバーが見つかりません", response.parsed_body["error"]
    assert_equal 0, VsmobileParseFailure.count
  end

  test "全試合そろったら、タイムスタンプを計算して Discord の連絡を予約する" do
    @event.update!(first_match_video_timestamp: 200, discord_thread_url: "https://discord.com/channels/1/2/3")
    other_html = @html.gsub("Bさん", "Eさん").gsub("Cさん", "Bさん").gsub("Dさん", "Cさん").gsub("Eさん", "Eさん")
    other_html = @html.gsub(">Bさん<", ">Eさん<").gsub(">Cさん<", ">Bさん<").gsub(">Dさん<", ">Cさん<")

    post "/api/vsmobile/matches", params: match_params(self_name: "Aさん").to_json, headers: headers_for(@users["Aさん"])
    post "/api/vsmobile/matches", params: match_params(self_name: "Aさん", match_ts: MATCH_TS + 420).merge(html: other_html).to_json, headers: headers_for(@users["Aさん"])

    assert_response :success
    assert_equal({ "status" => "imported", "match_number" => 2, "covered" => 2, "total" => 2, "remaining" => 0 }, response.parsed_body)
    assert_equal [ 200, 620 ], [ @match, @other ].map { |match| match.reload.video_timestamp }
    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ])
  end

  test "HTML が大きすぎれば受け付けない" do
    post "/api/vsmobile/matches", params: match_params.merge(html: "x" * (Api::Vsmobile::MatchesController::MAX_HTML_BYTES + 1)).to_json, headers: headers_for(@users["Bさん"])

    assert_response :content_too_large
    assert_nil @match.reload.game_started_at
  end

  test "同じ鍵からの送信が多すぎれば 429" do
    with_request_count(61) do
      get "/api/vsmobile/targets", headers: headers_for(@users["Aさん"])
    end

    assert_response :too_many_requests
    assert_match "送信が多すぎます", response.parsed_body["error"]
  end

  test "web.vsmobile.jp からのプリフライトに CORS のヘッダを返し、ほかのオリジンには返さない" do
    options "/api/vsmobile/matches", headers: { "Origin" => "https://web.vsmobile.jp", "Access-Control-Request-Method" => "POST", "Access-Control-Request-Headers" => "authorization, content-type" }

    assert_response :success
    assert_equal "https://web.vsmobile.jp", response.headers["Access-Control-Allow-Origin"]
    assert_match "POST", response.headers["Access-Control-Allow-Methods"]

    options "/api/vsmobile/matches", headers: { "Origin" => "https://evil.example.com", "Access-Control-Request-Method" => "POST" }
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  private

  # test 環境のキャッシュは null_store で回数を数えないので、数えた回数を差し替える
  def with_request_count(count)
    Rails.cache.define_singleton_method(:increment) { |*, **| count }
    yield
  ensure
    Rails.cache.singleton_class.remove_method(:increment)
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{user.vsmobile_token}", "Content-Type" => "application/json" }
  end

  def match_params(self_name: "Bさん", result_self: "win", match_ts: MATCH_TS)
    { event_id: @event.id, match_ts: match_ts, result_self: result_self, self_name: self_name, time: "10:12",
      game_date: "2026/11/07(土)", shop_name: "テスト店", html: @html }
  end

  def create_match(team1, team2)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    attributes = (team1 + team2).each_with_index.map do |name, index|
      { user: @users.fetch(name), mobile_suit: suit, team_number: index < 2 ? 1 : 2, position: index + 1 }
    end
    @event.matches.create!(played_at: Time.zone.local(2026, 11, 7, 10, 20) + (@event.matches.count * 7).minutes, winning_team: 1, match_players_attributes: attributes)
  end
end
