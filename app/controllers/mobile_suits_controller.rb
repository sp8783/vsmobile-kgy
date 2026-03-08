class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  # 公式Wikiに準拠したシリーズ表示順（カテゴリ → 作品時系列）
  SERIES_CATEGORY_ORDER = [
    "宇宙世紀シリーズ 地上波・劇場作品",
    "宇宙世紀シリーズ OVA・ゲーム・小説・漫画作品",
    "オルタナティブシリーズ",
    "ビルドシリーズ",
    "SD",
    "オリジナル",
  ].freeze

  SERIES_BY_CATEGORY = {
    "宇宙世紀シリーズ 地上波・劇場作品" => [
      "機動戦士ガンダム",
      "機動戦士Zガンダム",
      "機動戦士ガンダムZZ",
      "機動戦士ガンダム 逆襲のシャア",
      "機動戦士ガンダムF91",
      "機動戦士Vガンダム",
      "機動戦士ガンダムUC",
      "機動戦士ガンダムNT",
    ],
    "宇宙世紀シリーズ OVA・ゲーム・小説・漫画作品" => [
      "機動戦士ガンダムMSV",
      "機動戦士ガンダム0080 ポケットの中の戦争",
      "機動戦士ガンダム 第08MS小隊",
      "機動戦士ガンダム MS IGLOO",
      "機動戦士ガンダム外伝 THE BLUE DESTINY",
      "機動戦士ガンダム外伝 ミッシングリンク",
      "機動戦士ガンダム0083 STARDUST MEMORY",
      "ガンダム・センチネル",
      "機動戦士ガンダム ヴァルプルギス",
      "機動戦士ガンダム 逆襲のシャア MSV",
      "機動戦士ガンダム 逆襲のシャア ベルトーチカ・チルドレン",
      "THE-LIFE-SIZED νGUNDAM STATUE",
      "機動戦士ガンダム 閃光のハサウェイ",
      "機動戦士クロスボーン・ガンダム",
    ],
    "オルタナティブシリーズ" => [
      "機動武闘伝Gガンダム",
      "新機動戦記ガンダムW",
      "新機動戦記ガンダムW Endless Waltz",
      "機動新世紀ガンダムX",
      "∀ガンダム",
      "機動戦士ガンダムSEED",
      "機動戦士ガンダムSEED DESTINY",
      "機動戦士ガンダムSEED C.E.73 STARGAZER",
      "機動戦士ガンダムSEED FREEDOM",
      "機動戦士ガンダムSEED ASTRAY",
      "機動戦士ガンダム00",
      "劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-",
      "機動戦士ガンダム00V",
      "機動戦士ガンダムAGE",
      "ガンダム Gのレコンギスタ",
      "機動戦士ガンダム 鉄血のオルフェンズ",
      "機動戦士ガンダム サンダーボルト",
      "機動戦士ガンダム 水星の魔女",
      "機動戦士Gundam GQuuuuuuX",
    ],
    "ビルドシリーズ" => [
      "ガンダムビルドファイターズ",
      "ガンダムビルドファイターズトライ",
      "ガンダムビルドファイターズA-R",
      "ガンダムビルドダイバーズ",
      "ガンダムビルドダイバーズRe:RISE",
    ],
    "SD" => [
      "SDガンダム外伝",
    ],
    "オリジナル" => [
      "ガンダムEXA",
      "Project N-EXTREME",
    ],
  }.freeze

  def index
    suits = MobileSuit.all.order(:id)

    # 全機体をシリーズ→コスト別にグルーピング（ID順を維持）
    all_by_series = suits.group_by(&:series).transform_values do |series_suits|
      series_suits.group_by(&:cost)
    end

    # 公式順でカテゴリ・シリーズを並べる
    @series_by_category = {}
    SERIES_CATEGORY_ORDER.each do |category|
      ordered_series = {}
      (SERIES_BY_CATEGORY[category] || []).each do |series|
        ordered_series[series] = all_by_series[series] if all_by_series.key?(series)
      end
      @series_by_category[category] = ordered_series unless ordered_series.empty?
    end

    @costs = [ 3000, 2500, 2000, 1500 ]
    @total_count = suits.count
  end
end
