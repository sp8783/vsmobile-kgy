# db/data/units.json（exvs2ib-wiki-scraper の出力）を機体マスタに反映する。
# Wiki のページ ID で突き合わせ、何度実行しても同じ結果になる（起動時に毎回実行する）
class MobileSuitCatalogSync
  Result = Struct.new(:created, :updated, :unchanged, keyword_init: true)

  DEFAULT_PATH = Rails.root.join("db/data/units.json")

  def initialize(path: DEFAULT_PATH)
    @path = path
  end

  def call
    counts = Hash.new(0)

    MobileSuit.transaction do
      units.each.with_index(1) do |unit, position|
        suit = find_suit(unit)
        suit.assign_attributes(attributes_for(unit, position))

        status = if suit.new_record? then :created
        elsif suit.changed? then :updated
        else :unchanged
        end
        suit.save! if suit.changed?
        counts[status] += 1
      end
    end

    Result.new(created: counts[:created], updated: counts[:updated], unchanged: counts[:unchanged])
  end

  private

  attr_reader :path

  def units
    JSON.parse(File.read(path))["units"]
  end

  # ページ ID が未設定の既存機体は、名前（半角/全角カッコの表記ゆれを含む）で突き合わせる
  def find_suit(unit)
    MobileSuit.find_by(wiki_page_id: unit["pageId"].to_i) ||
      MobileSuit.find_by(wiki_page_id: nil, name: [ unit["name"], unit["name"].tr("()", "（）") ]) ||
      MobileSuit.new
  end

  def attributes_for(unit, position)
    metadata = unit["metadata"] || {}
    {
      wiki_page_id:   unit["pageId"].to_i,
      name:           unit["name"],
      series:         unit["series"],
      cost:           unit["cost"].to_i,
      position:       position,
      wiki_url:       unit["wikiUrl"],
      image_filename: unit["imageLocalPath"].presence && File.basename(unit["imageLocalPath"]),
      durability:     metadata["durability"]&.to_i.presence,
      bd_count:       metadata["bdCount"].presence,
      red_lock_range: metadata["redLockRange"].presence
    }
  end
end
