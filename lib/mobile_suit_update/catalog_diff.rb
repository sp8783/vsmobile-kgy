module MobileSuitUpdate
  # 今の units.json と Wiki から取り直した units.json を、アプリが使う項目だけで比べる
  # （取得日時・パイロット名・タグなど、アプリが使わない項目の違いは無視する）
  class CatalogDiff
    # 比べる項目と、PR 本文・告知文での呼び名
    FIELDS = {
      name: "機体名", cost: "コスト", series: "シリーズ",
      durability: "耐久値", bd_count: "BD回数", red_lock_range: "赤ロック距離"
    }.freeze
    # 新しい機体でこれが欠けていたら、PR を下書きにする
    REQUIRED = { image: "画像", durability: "耐久値", bd_count: "BD回数", red_lock_range: "赤ロック距離" }.freeze

    # fields は { durability: [ 650, 600 ] } のように、変わった項目の変更前・変更後
    Change = Data.define(:before, :after, :fields)
    Incomplete = Data.define(:suit, :missing)

    attr_reader :added, :removed, :changed, :position_only_count

    # image_dir: 取り直したあとの機体画像の置き場所（新しい機体の画像があるかを確かめる）
    def initialize(before_units, after_units, image_dir:)
      before = index(before_units)
      after = index(after_units)
      @image_dir = Pathname(image_dir)

      @added = after.except(*before.keys).values
      @removed = before.except(*after.keys).values
      @changed = []
      @position_only_count = 0
      (after.keys & before.keys).each do |page_id|
        fields = FIELDS.keys.filter_map { |key| [ key, [ before[page_id][key], after[page_id][key] ] ] unless before[page_id][key] == after[page_id][key] }.to_h
        if fields.any?
          @changed << Change.new(before: before[page_id], after: after[page_id], fields:)
        elsif before[page_id][:position] != after[page_id][:position]
          @position_only_count += 1
        end
      end
    end

    # 並び順だけの変化では PR を作らない（ほかの変化と一緒に反映する）
    def changes?
      added.any? || removed.any? || changed.any?
    end

    def incomplete
      added.filter_map do |suit|
        missing = REQUIRED.filter_map { |key, label| label if missing?(suit, key) }
        Incomplete.new(suit:, missing:) if missing.any?
      end
    end

    def complete?
      incomplete.empty?
    end

    private

    attr_reader :image_dir

    def index(units)
      units.each.with_index(1).to_h do |unit, position|
        attributes = MobileSuitCatalogSync.attributes_for(unit, position)
        [ attributes[:wiki_page_id], attributes ]
      end
    end

    def missing?(suit, key)
      return suit[:image_filename].blank? || !image_dir.join(suit[:image_filename]).exist? if key == :image

      suit[key].blank?
    end
  end
end
