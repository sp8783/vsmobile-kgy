require "test_helper"

class MobileSuitUpdate::RefresherTest < ActiveSupport::TestCase
  include MobileSuitUnitHelper

  setup do
    @root = Pathname(Dir.mktmpdir)
    @scraper_dir = Pathname(Dir.mktmpdir)
    @root.join("db/data").mkpath
    @root.join("public/mobile_suits").mkpath
    @root.join("config").mkpath
    @root.join("config/mobile_suits.yml").write({ "exclude_page_ids" => [ 999 ] }.to_yaml)
    @scraper_dir.join("config.yaml").write({ "scraper" => { "base_url" => "https://example.test" }, "exclude_page_ids" => [] }.to_yaml)
    write_units(@root.join("db/data/units.json"), [ suit_unit(1, "機体A", durability: "650"), suit_unit(2, "旧名") ])
    @root.join("public/mobile_suits/1_機体A.png").write("A")
    @root.join("public/mobile_suits/2_旧名.png").write("old")
  end

  teardown do
    FileUtils.remove_entry(@root)
    FileUtils.remove_entry(@scraper_dir)
  end

  test "今のデータと画像を起点にスクレイパーを全件の取り直しで動かし、vsmobile-kgy の除外設定を渡す" do
    calls = []
    refresher(scrape: ->(config) {
      calls << config
      assert_equal %w[1_機体A.png 2_旧名.png], Pathname(config["output"]["image_dir"]).children.map { |path| path.basename.to_s }.sort
    }) { |command, chdir| calls << [ command, chdir ] }.call

    command, chdir = calls.first
    assert_equal [ "python3", "scraper.py", "--config" ], command.first(3)
    assert_equal "--force", command.last
    assert_equal @scraper_dir.to_s, chdir
    assert_equal [ 999 ], calls.last["exclude_page_ids"]
    assert_equal "https://example.test", calls.last.dig("scraper", "base_url")
  end

  test "変化があれば units.json を書き換え、新しい画像を足し、名前が変わった機体の古い画像を消す" do
    result = refresher(scrape: ->(config) {
      units = [ suit_unit(1, "機体A", durability: "600"), suit_unit(2, "新名"), suit_unit(3, "機体C") ]
      write_units(Pathname(config["output"]["json_path"]), units)
      images = Pathname(config["output"]["image_dir"])
      images.join("2_旧名.png").rename(images.join("2_新名.png"))
      images.join("3_機体C.png").write("C")
    }).call

    assert_equal [ "機体C" ], result.diff.added.map { |suit| suit[:name] }
    assert_equal [ 600, "新名", "機体C" ], read_units.then { |units| [ units[0].dig("metadata", "durability").to_i, units[1]["name"], units[2]["name"] ] }
    assert_equal %w[1_機体A.png 2_新名.png 3_機体C.png], @root.join("public/mobile_suits").children.map { |path| path.basename.to_s }.sort
  end

  test "変化がなければ何も書き換えない" do
    original = @root.join("db/data/units.json").read

    result = refresher(scrape: ->(config) {
      write_units(Pathname(config["output"]["json_path"]), [ suit_unit(1, "機体A", durability: "650").merge("pilot" => "取り直した"), suit_unit(2, "旧名") ])
    }).call

    assert_not result.diff.changes?
    assert_equal original, @root.join("db/data/units.json").read
  end

  test "取り直しで値が取れなかった項目は、今の値を残す" do
    result = refresher(scrape: ->(config) {
      write_units(Pathname(config["output"]["json_path"]), [ suit_unit(1, "機体A", durability: nil, image: false), suit_unit(2, "旧名") ])
    }).call

    assert_not result.diff.changes?
    assert_equal [ "機体A（画像・耐久値）" ], result.kept
  end

  private

  def refresher(scrape:, &observer)
    runner = ->(*command, chdir:) {
      observer&.call(command, chdir)
      scrape.call(YAML.safe_load_file(command[command.index("--config") + 1]))
    }
    MobileSuitUpdate::Refresher.new(scraper_dir: @scraper_dir, root: @root, python: "python3", runner:)
  end

  def write_units(path, units)
    path.write(JSON.pretty_generate("units" => units, "metadata" => { "scrapedAt" => Time.current.iso8601 }))
  end

  def read_units
    JSON.parse(@root.join("db/data/units.json").read)["units"]
  end
end
