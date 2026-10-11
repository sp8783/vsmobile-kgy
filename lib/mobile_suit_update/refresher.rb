module MobileSuitUpdate
  # スクレイパー（exvs2ib-wiki-scraper）で全機体を Wiki から取り直し、アプリの機体データと比べる。
  # 変化があれば db/data/units.json と public/mobile_suits の画像を書き換える
  class Refresher
    DATA_PATH = "db/data/units.json".freeze
    IMAGE_DIR = "public/mobile_suits".freeze
    SETTINGS_PATH = "config/mobile_suits.yml".freeze
    # 取り直しで値が取れなかったとき（Wiki の一時的な不調など）は、今の値を残す項目
    KEEP_KEYS = { "durability" => "耐久値", "bdCount" => "BD回数", "redLockRange" => "赤ロック距離" }.freeze

    # kept: 値が取れず今の値を残した機体（"機体名（耐久値）" の形）
    Result = Data.define(:diff, :kept)

    def initialize(scraper_dir:, root: Rails.root, python: ENV.fetch("SCRAPER_PYTHON", "python3"),
                   runner: ->(*command, chdir:) { system(*command, chdir:, exception: true) })
      @scraper_dir = Pathname(scraper_dir)
      @root = Pathname(root)
      @python = python
      @runner = runner
    end

    def call
      Dir.mktmpdir("mobile-suit-update") do |dir|
        work = Pathname(dir)
        prepare(work)
        runner.call(python, "scraper.py", "--config", work.join("config.yml").to_s, "--force", chdir: scraper_dir.to_s)

        before = JSON.parse(root.join(DATA_PATH).read)
        after = JSON.parse(work.join("units.json").read)
        kept = keep_current_values(before["units"], after["units"])
        diff = CatalogDiff.new(before["units"], after["units"], image_dir: work.join("images"))
        apply(after, work.join("images")) if diff.changes?
        Result.new(diff:, kept:)
      end
    end

    private

    attr_reader :scraper_dir, :root, :python, :runner

    # 今のデータを起点にする（スクレイパーは既存の units.json と画像を引き継ぎ、新しい機体の画像だけを取りに行く）
    def prepare(work)
      FileUtils.cp(root.join(DATA_PATH), work.join("units.json"))
      FileUtils.mkdir_p(work.join("images"))
      FileUtils.cp(Dir[root.join(IMAGE_DIR, "*.png").to_s], work.join("images"))
      work.join("config.yml").write(scraper_config(work).to_yaml)
    end

    def scraper_config(work)
      YAML.safe_load_file(scraper_dir.join("config.yaml")).merge(
        "output" => { "json_path" => work.join("units.json").to_s, "image_dir" => work.join("images").to_s, "download_images" => true },
        "logging" => { "level" => "INFO", "file" => work.join("scraper.log").to_s },
        "exclude_page_ids" => settings.fetch("exclude_page_ids", [])
      )
    end

    def settings
      YAML.safe_load_file(root.join(SETTINGS_PATH)) || {}
    end

    def keep_current_values(before_units, after_units)
      before_by_id = before_units.index_by { |unit| unit["pageId"] }
      after_units.flat_map do |unit|
        current = before_by_id[unit["pageId"]]
        next [] unless current

        kept = []
        if unit["imageLocalPath"].blank? && current["imageLocalPath"].present?
          unit["imageLocalPath"] = current["imageLocalPath"]
          kept << "画像"
        end
        metadata = (unit["metadata"] ||= {})
        KEEP_KEYS.each do |key, label|
          next unless metadata[key].blank? && current.dig("metadata", key).present?

          metadata[key] = current.dig("metadata", key)
          kept << label
        end
        kept.any? ? [ "#{unit['name']}（#{kept.join('・')}）" ] : []
      end
    end

    def apply(after, work_images)
      # スクレイパーの出力と同じ形（インデント 2・末尾の改行なし）にして、差分を小さくする
      root.join(DATA_PATH).write(JSON.pretty_generate(after))

      image_dir = root.join(IMAGE_DIR)
      after["units"].each do |unit|
        filename = unit["imageLocalPath"].presence && File.basename(unit["imageLocalPath"])
        next unless filename && work_images.join(filename).exist?

        FileUtils.cp(work_images.join(filename), image_dir.join(filename)) unless image_dir.join(filename).exist?
        # 機体名が変わると画像名も変わるので、同じページ ID の古い画像を消す
        Dir[image_dir.join("#{unit['pageId']}_*.png").to_s].each { |path| File.delete(path) unless File.basename(path) == filename }
      end
    end
  end
end
