require "test_helper"

class MobileSuitCatalogSyncTest < ActiveSupport::TestCase
  test "新しい機体を作成し、並び順・画像名・スペックを反映する" do
    result = sync(unit(page_id: 772, name: "ブラックナイトスコード カルラ", cost: "3000"))

    assert_equal 1, result.created
    suit = MobileSuit.find_by!(wiki_page_id: 772)
    assert_equal [ "ブラックナイトスコード カルラ", 3000, 1, "772_ブラックナイトスコード カルラ.png", 650, "7" ],
                 [ suit.name, suit.cost, suit.position, suit.image_filename, suit.durability, suit.bd_count ]
  end

  test "ページ ID で突き合わせるので、Wiki 側で機体名が変わっても同じ機体を更新する" do
    suit = MobileSuit.create!(name: "旧名", series: "テスト", cost: 2500, wiki_page_id: 100)

    result = sync(unit(page_id: 100, name: "新名", cost: "2500"))

    assert_equal [ 0, 1 ], [ result.created, result.updated ]
    assert_equal "新名", suit.reload.name
    assert_equal 1, MobileSuit.count
  end

  test "ページ ID のない既存機体は名前（全角カッコの表記ゆれを含む）で突き合わせ、ページ ID を埋める" do
    suit = MobileSuit.create!(name: "リ・ガズィ（アムロ搭乗）", series: "テスト", cost: 2500)

    sync(unit(page_id: 783, name: "リ・ガズィ(アムロ搭乗)", cost: "2500"))

    assert_equal 783, suit.reload.wiki_page_id
    assert_equal 1, MobileSuit.count
  end

  test "何度実行しても同じ結果になる" do
    units = [ unit(page_id: 1, name: "機体A", cost: "3000"), unit(page_id: 2, name: "機体B", cost: "1500") ]
    sync(*units)

    result = sync(*units)

    assert_equal [ 0, 0, 2 ], [ result.created, result.updated, result.unchanged ]
    assert_equal [ [ 1, 1 ], [ 2, 2 ] ], MobileSuit.order(:position).pluck(:wiki_page_id, :position)
  end

  private

  def sync(*units)
    file = Tempfile.new([ "units", ".json" ])
    file.write({ units: units }.to_json)
    file.close
    MobileSuitCatalogSync.new(path: file.path).call
  ensure
    file&.unlink
  end

  def unit(page_id:, name:, cost:)
    {
      pageId: page_id.to_s,
      name: name,
      cost: cost,
      series: "テスト",
      wikiUrl: "https://w.atwiki.jp/exvs2infiniteboost/pages/#{page_id}.html",
      imageLocalPath: "./output/images/#{page_id}_#{name}.png",
      metadata: { durability: "650", bdCount: "7", redLockRange: "A" }
    }
  end
end
