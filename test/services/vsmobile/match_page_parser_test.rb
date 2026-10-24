require "test_helper"

# VS.モバイルの試合詳細ページの解析（scraper/parsers/match.py・timeline.py の移植）
class Vsmobile::MatchPageParserTest < ActiveSupport::TestCase
  setup do
    @parsed = Vsmobile::MatchPageParser.new(file_fixture("vsmobile_match_detail.html").read, result_self: "win", self_name: "Bさん").call
  end

  test "2 チームのメンバーを、名前・アイコン・プロフィール・マスタリー・都道府県とともに読む" do
    team_a = @parsed["team_a"]
    assert_equal "チームA", team_a["team_name"]
    assert_equal %w[Aさん Bさん], team_a["players"].map { |player| player["name"] }
    assert_equal %w[Cさん Dさん], @parsed["team_b"]["players"].map { |player| player["name"] }

    player = team_a["players"].first
    assert_equal "https://img.example.com/icons/1.png", player["icon_url"], "アイコンの URL はクエリを外す"
    assert_equal "p-a", player["player_param"]
    assert_equal "m-gold", player["mastery"]
    assert_equal "東京都", player["prefecture"]
    assert_nil @parsed["team_b"]["players"].first["mastery"]
  end

  test "成績はアイコンで結びつけ、数値にする" do
    b = @parsed["team_a"]["players"].last
    assert_equal({ "score" => 1500, "kills" => 3, "deaths" => 0, "damage_dealt" => 910, "damage_received" => 300, "exburst_damage" => 240, "match_rank" => 1 },
                 b.slice("score", "kills", "deaths", "damage_dealt", "damage_received", "exburst_damage", "match_rank"))
    assert_equal 4, @parsed["team_b"]["players"].last["match_rank"]
  end

  test "自分の勝敗と名前から、チームの勝敗と is_self を決める" do
    assert_equal "win", @parsed["team_a"]["result"]
    assert_equal "lose", @parsed["team_b"]["result"]
    assert_equal [ false, true, false, false ], Vsmobile::MatchPageParser.player_names(@parsed).size.times.map { |i|
      (@parsed["team_a"]["players"] + @parsed["team_b"]["players"])[i]["is_self"]
    }
  end

  test "タイムラインのスクリプトを 1/100 秒の時刻に直して読む" do
    timeline = @parsed["timeline_raw"]
    assert_equal({ "team1-1" => "https://img.example.com/icons/1.png", "team1-2" => "https://img.example.com/icons/2.png",
                   "team2-1" => "https://img.example.com/icons/3.png", "team2-2" => "https://img.example.com/icons/4.png" }, timeline["groups"])
    assert_equal 4, timeline["events"].size

    ex = timeline["events"][0]
    assert_equal({ "group" => "team1-1", "class_name" => "ex", "is_point" => false, "start_cs" => 4010, "start_str" => "0:40.10", "end_cs" => 6500, "end_str" => "1:05.00" }, ex)
    down = timeline["events"][1]
    assert_equal "down", down["class_name"]
    assert down["is_point"]
    assert_equal 6050, down["start_cs"]
    assert_nil down["end_cs"], "start_time が更新されたら end_time はいったん消える"
    assert timeline["events"][3]["is_point"], "type: 'point'（空白あり）も読む"

    assert_equal 15015, timeline["game_end_cs"]
    assert_equal "2:30.15", timeline["game_end_str"]
  end

  test "メンバーの箱がなければ（ログインページなど）解析エラー" do
    error = assert_raises(Vsmobile::MatchPageParser::ParseError) { Vsmobile::MatchPageParser.new("<html><body>ログイン</body></html>").call }
    assert_match "ログインしていない", error.message
  end

  test "4 人の名前をチーム A → B の順に取り出せる" do
    assert_equal %w[Aさん Bさん Cさん Dさん], Vsmobile::MatchPageParser.player_names(@parsed)
  end
end
