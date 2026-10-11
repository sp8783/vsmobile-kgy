require "test_helper"

class MobileSuitUpdate::CatalogDiffTest < ActiveSupport::TestCase
  include MobileSuitUnitHelper

  setup do
    @image_dir = Pathname(Dir.mktmpdir)
  end

  teardown do
    FileUtils.remove_entry(@image_dir)
  end

  test "アプリが使う項目の変化だけを拾い、取得日時などほかの項目の違いは無視する" do
    before = [ suit_unit(1, "機体A", durability: "650"), suit_unit(2, "機体B") ]
    after = [ suit_unit(1, "機体A", durability: "600").merge("pilot" => "別のパイロット"), suit_unit(2, "機体B").merge("tags" => [ "新しいタグ" ]) ]

    diff = diff(before, after)

    assert diff.changes?
    assert_equal [ 1 ], diff.changed.map { |change| change.after[:wiki_page_id] }
    assert_equal({ durability: [ 650, 600 ] }, diff.changed.first.fields)
  end

  test "新しい機体・消えた機体を拾う" do
    diff = diff([ suit_unit(1, "機体A"), suit_unit(2, "機体B") ], [ suit_unit(1, "機体A"), suit_unit(3, "機体C") ])

    assert_equal [ "機体C" ], diff.added.map { |suit| suit[:name] }
    assert_equal [ "機体B" ], diff.removed.map { |suit| suit[:name] }
  end

  test "並び順だけの変化は数えるが、それだけでは変化とみなさない" do
    diff = diff([ suit_unit(1, "機体A"), suit_unit(2, "機体B") ], [ suit_unit(2, "機体B"), suit_unit(1, "機体A") ])

    assert_not diff.changes?
    assert_equal 2, diff.position_only_count
  end

  test "新しい機体の画像・耐久値・BD回数・赤ロック距離が欠けていれば、情報不足とする" do
    write_image(3, "機体C")
    after = [ suit_unit(3, "機体C", red_lock_range: ""), suit_unit(4, "機体D", durability: nil), suit_unit(5, "機体E") ]
    write_image(5, "機体E")

    diff = diff([], after)

    assert_not diff.complete?
    assert_equal({ "機体C" => [ "赤ロック距離" ], "機体D" => [ "画像", "耐久値" ] },
                 diff.incomplete.to_h { |item| [ item.suit[:name], item.missing ] })
  end

  test "新しい機体の情報がそろっていれば complete" do
    write_image(3, "機体C")

    assert diff([], [ suit_unit(3, "機体C") ]).complete?
  end

  private

  def diff(before, after)
    MobileSuitUpdate::CatalogDiff.new(before, after, image_dir: @image_dir)
  end

  def write_image(page_id, name)
    @image_dir.join("#{page_id}_#{name}.png").write("png")
  end
end
