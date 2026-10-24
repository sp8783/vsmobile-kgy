module Vsmobile
  # VS.モバイルの試合詳細（match_detail）ページの HTML から、exvs2ib-vsmobile-scraper の scrape.py と同じ形のデータを作る。
  # scraper/parsers/match.py と timeline.py の移植。ブックマークレット（public/vsm/collect.js）はページの HTML をそのまま送り、
  # 解析はここで行う（直しても参加者に配り直さなくてよい。テストも書ける）
  class MatchPageParser
    class ParseError < StandardError; end

    STAT_KEYS = {
      "スコア" => "score",
      "撃墜" => "kills",
      "被撃墜" => "deaths",
      "与ダメージ" => "damage_dealt",
      "被ダメージ" => "damage_received",
      "EXバーストダメージ" => "exburst_damage"
    }.freeze

    # result_self: 対戦履歴の一覧での自分の勝敗（win / lose）。self_name: ログインしている人の VS.モバイルでの名前
    def initialize(html, result_self: nil, self_name: nil)
      # HTML5 のパーサーで読む（h3 の中の p など、libxml2 の HTML4 パーサーだと組み替えられてしまう入れ子を VS.モバイルが使っている）
      @doc = Nokogiri::HTML5(html.to_s)
      @result_self = result_self
      @self_name = self_name
    end

    # { "team_a" => { team_name, result, players: [...] }, "team_b" => {...}, "timeline_raw" => {...} か nil }
    def call
      member_boxes = boxes_in("panel1")
      raise ParseError, "試合のメンバーが見つかりません（VS.モバイルにログインしていないか、ページの形が変わった可能性があります）" if member_boxes.size < 2

      team_a = parse_team_members(member_boxes[0])
      team_b = parse_team_members(member_boxes[1])
      [ team_a, team_b ].each { |team| team["players"].each { |player| player["is_self"] = player["name"] == self_name } }

      score_boxes = boxes_in("panel3")
      merge_scores(team_a, parse_score_box(score_boxes[0])) if score_boxes[0]
      merge_scores(team_b, parse_score_box(score_boxes[1])) if score_boxes[1]

      team_a["result"] = result_self
      team_b["result"] = opposite_result(result_self)

      { "team_a" => team_a, "team_b" => team_b, "timeline_raw" => parse_timeline }
    end

    # 4 人の名前（チーム A → チーム B の順）
    def self.player_names(parsed)
      %w[team_a team_b].flat_map { |team| parsed.dig(team, "players")&.map { |player| player["name"] } || [] }.compact
    end

    private

    attr_reader :doc, :result_self, :self_name

    # #panelN の直下の div.box
    def boxes_in(panel_id)
      panel = doc.at_css("##{panel_id}")
      return [] unless panel

      panel.xpath("./div[contains(concat(' ', normalize-space(@class), ' '), ' box ')]")
    end

    def parse_team_members(box)
      {
        "team_name" => box.at_css("h3 p.tag-name")&.text.to_s.strip,
        "players" => box.css("li.item").map do |item|
          profile_href = item.at_css('a.right-arrow[href*="profile"]')&.[]("href")
          mastery_classes = item.at_css("span.mastery")&.[]("class").to_s.split - [ "mastery" ]
          {
            "name" => item.at_css("span.name")&.text.to_s.strip,
            "player_param" => profile_href && query_value(profile_href, "param"),
            "icon_url" => icon_url(item),
            "mastery" => mastery_classes.first,
            "prefecture" => item.at_css("p.col-stand.fz-s")&.text&.strip
          }
        end
      }
    end

    def parse_score_box(box)
      box.css("li.item").map do |item|
        rank_class = item["class"].to_s.split.find { |name| name.start_with?("rank-band") }
        scores = item.css("dl").each_with_object({}) do |dl, result|
          key = STAT_KEYS[dl.at_css("dt")&.text.to_s.strip]
          dd = dl.at_css("dd")
          next unless key && dd

          raw = dd.xpath("text()").map { |node| node.text.strip }.join.strip
          result[key] = Integer(raw, exception: false) || raw
        end
        { "icon_url" => icon_url(item), "match_rank" => rank_class && Integer(rank_class.delete_prefix("rank-band"), exception: false) }.merge(scores)
      end
    end

    # 成績はアイコンの URL でメンバーに結びつける（同じアイコンが 2 人いたら先に出た人から順に）
    def merge_scores(team, score_list)
      used = []
      team["players"].each do |player|
        index = score_list.each_index.find { |i| !used.include?(i) && score_list[i]["icon_url"] == player["icon_url"] }
        next unless index

        used << index
        player.merge!(score_list[index].except("icon_url"))
      end
    end

    def icon_url(item)
      item.at_css("img.item-icon-img[data-original]")&.[]("data-original").to_s.split("?").first.to_s
    end

    def query_value(href, key)
      Rack::Utils.parse_query(URI.parse(href).query.to_s)[key]
    rescue URI::InvalidURIError
      nil
    end

    def opposite_result(result)
      case result
      when "win" then "lose"
      when "lose" then "win"
      end
    end

    # --- タイムライン（#panel2 の vis.js のスクリプトを正規表現で読む） ---

    GROUP_RE = /id:'(team\d+-\d+)',content:'<img src="([^"]+)"/
    START_RE = /var start_time\s*=\s*new Date\(0,\s*0,\s*0,\s*(\d+),\s*(\d+),\s*(\d+)\)/
    END_RE = /var end_time\s*=\s*new Date\(0,\s*0,\s*0,\s*(\d+),\s*(\d+),\s*(\d+)\)/
    EVENT_GROUP_RE = /group:\s*"(team\d+-\d+)"/
    CLASS_RE = /className:\s*'([^']+)'/
    GAME_END_RE = /timeline\.addCustomTime\(new Date\(0,\s*0,\s*0,\s*(\d+),\s*(\d+),\s*(\d+)\),\s*'game-over'\)/

    def parse_timeline
      script = doc.at_css("#panel2 script")&.text.to_s
      return nil if script.strip.empty?

      groups = script.scan(GROUP_RE).to_h { |group_id, src| [ group_id, src.split("?").first ] }
      events = []
      start_cs = end_cs = nil
      script.each_line do |raw_line|
        line = raw_line.strip
        if (m = START_RE.match(line))
          start_cs = to_cs(m)
          end_cs = nil
        elsif (m = END_RE.match(line))
          end_cs = to_cs(m)
        elsif line.include?("dataset.push(") && (group = EVENT_GROUP_RE.match(line))
          events << {
            "group" => group[1],
            "start_cs" => start_cs, "start_str" => cs_to_str(start_cs),
            "end_cs" => end_cs, "end_str" => cs_to_str(end_cs),
            "class_name" => CLASS_RE.match(line)&.[](1),
            "is_point" => line.include?("type:'point'") || line.include?("type: 'point'")
          }
        end
      end
      game_end_cs = (m = GAME_END_RE.match(script)) && to_cs(m)

      { "groups" => groups, "events" => events, "game_end_cs" => game_end_cs, "game_end_str" => cs_to_str(game_end_cs) }
    end

    # new Date(0, 0, 0, A, B, C) の A・B・C を 1/100 秒に
    def to_cs(match)
      match[1].to_i * 6000 + match[2].to_i * 100 + match[3].to_i
    end

    def cs_to_str(cs)
      return nil if cs.nil?

      minutes, rest = cs.divmod(6000)
      seconds, centis = rest.divmod(100)
      format("%d:%02d.%02d", minutes, seconds, centis)
    end
  end
end
