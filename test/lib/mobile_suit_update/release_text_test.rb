require "test_helper"

class MobileSuitUpdate::ReleaseTextTest < ActiveSupport::TestCase
  include MobileSuitUnitHelper

  test "調整だけのときは、これまでのリリース告知と同じ形で機体データの更新を告知する" do
    note = release_note(
      [ suit_unit(684, "TX-ff104 アリュゼウス", durability: "650"), suit_unit(700, "ウイングガンダムフェニーチェ", durability: "660") ],
      [ suit_unit(684, "TX-ff104 アリュゼウス", durability: "600"), suit_unit(700, "ウイングガンダムフェニーチェ", durability: "640") ]
    )

    assert_equal "🔧 v2.3.2 リリース！ 機体データを更新", note["title"]
    assert_equal <<~BODY, note["body"]
      今回は機体データの更新アップデートです。

      ## 🔧 機体データの更新
      - `TX-ff104 アリュゼウス`（耐久値 650 → 600）
      - `ウイングガンダムフェニーチェ`（耐久値 660 → 640）
    BODY
    assert_equal <<~DISCORD, note["discord"], "調整値だけの更新は @everyone を付けない"
      # :sparkles: **VS.モバイル for KGY v2.3.2 リリース！**

      v2.3.2をリリースしました :tada:
      今回は機体データの更新アップデートです！

      :link: **アプリURL**
      https://vsm-kgy.com/

      ──────────────────────────────

      ## :wrench: **機体データの更新**
      * Wiki の最新の情報に合わせて、機体データを更新しました :crossed_swords:
        * `TX-ff104 アリュゼウス`（耐久値 650 → 600）
        * `ウイングガンダムフェニーチェ`（耐久値 660 → 640）

      ──────────────────────────────

      **バグの報告**や**機能要望**は引き続き <#1462281876524896458> へお願いします :person_bowing:
    DISCORD
  end

  test "新しい機体と調整の両方があるときは、新機体・機体データの更新の順に節を並べる" do
    note = release_note(
      [ suit_unit(1, "機体A", bd_count: "7") ],
      [ suit_unit(1, "機体A", bd_count: "8"), suit_unit(772, "ブラックナイトスコード カルラ", series: "機動戦士ガンダムSEED FREEDOM"),
        suit_unit(783, "リ・ガズィ(アムロ搭乗)", cost: "2500", series: "機動戦士ガンダム 逆襲のシャア") ]
    )

    assert_equal "🆕 v2.3.2 リリース！ 新機体2機の追加・機体データを更新", note["title"]
    assert_includes note["body"], "今回は新機体2機の追加と、機体データの更新アップデートです。\n\n## 🆕 新機体\n- `ブラックナイトスコード カルラ`（コスト3000 / 機動戦士ガンダムSEED FREEDOM）\n- `リ・ガズィ(アムロ搭乗)`（コスト2500 / 機動戦士ガンダム 逆襲のシャア）\n\n## 🔧 機体データの更新\n- `機体A`（BD回数 7 → 8）"
    assert_includes note["discord"], "今回は新機体2機の追加と、機体データの更新アップデートです！"
    assert_includes note["discord"], "## :new: **新機体**\n* **ブラックナイトスコード カルラ** と **リ・ガズィ(アムロ搭乗)** を追加しました :crossed_swords:\n  * `ブラックナイトスコード カルラ`（コスト3000 / 機動戦士ガンダムSEED FREEDOM）"
    assert_operator note["discord"].index(":new:"), :<, note["discord"].index(":wrench:")
  end

  test "新しい機体だけのときは「新機体N機を追加」" do
    note = release_note([], [ suit_unit(772, "ブラックナイトスコード カルラ") ])

    assert_equal "🆕 v2.3.2 リリース！ 新機体1機を追加", note["title"]
    assert note["discord"].start_with?("@everyone\n\n"), "新機体の追加は @everyone で知らせる"
    assert_includes note["discord"], "今回は新機体1機の追加アップデートです！"
    assert_includes note["discord"], "* **ブラックナイトスコード カルラ** を追加しました :crossed_swords:"
    assert_not_includes note["discord"], ":wrench:"
  end

  test "名前が変わった機体は「旧名 → 新名」、ほかの項目の変化はかっこにまとめる" do
    note = release_note([ suit_unit(1, "旧名", durability: "600", red_lock_range: "") ], [ suit_unit(1, "新名", durability: "620", red_lock_range: "120m") ])

    assert_includes note["body"], "- `旧名` → `新名`（耐久値 600 → 620、赤ロック距離 なし → 120m）"
  end

  test "Discord の文字数の上限を超えるときは、調整した機体を「ほか N 機」にまとめる" do
    before = (1..80).map { |i| suit_unit(i, "とても長い名前の機体その#{i}番", durability: "600") }
    after = (1..80).map { |i| suit_unit(i, "とても長い名前の機体その#{i}番", durability: "620") }

    discord = release_note(before, after)["discord"]

    assert_operator discord.length, :<=, ReleaseAnnouncer::DISCORD_LIMIT
    assert_match(/  \* ほか\d+機\n/, discord)
    assert discord.end_with?(":person_bowing:\n")
  end

  test "ファイルに書いた告知文は ReleaseAnnouncer がそのまま読める" do
    dir = Pathname(Dir.mktmpdir)
    dir.join("v2.3.2.yml").write(release_note([ suit_unit(1, "機体A", durability: "650") ], [ suit_unit(1, "機体A", durability: "600") ]).to_yaml)

    note = ReleaseAnnouncer.load_notes(dir).sole

    assert_equal [ "v2.3.2", "🔧 v2.3.2 リリース！ 機体データを更新" ], [ note.version, note.title ]
    assert_not_includes note.discord, "@everyone"
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  private

  def release_note(before, after)
    diff = MobileSuitUpdate::CatalogDiff.new(before, after, image_dir: Dir.tmpdir)
    MobileSuitUpdate::ReleaseText.new(diff, version: "v2.3.2").to_release_note
  end
end
