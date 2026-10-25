module Api
  module Vsmobile
    # POST /api/vsmobile/matches
    # ブックマークレットが VS.モバイルの試合詳細ページの HTML をそのまま送ってくる。ここで解析し、イベントのどの試合かを決めて取り込む。
    # body（JSON）: event_id, match_ts, result_self（win / lose）, self_name, time, game_date, shop_name, html
    class MatchesController < BaseController
      # 試合詳細ページは数百 KB。これを大きく超えるものは受け付けない
      MAX_HTML_BYTES = 2.megabytes

      # 送った人のニックネームが試合の 4 人にいない（アプリと VS.モバイルで名前が違う）
      class NicknameMismatchError < StandardError; end

      def create
        event = Event.find_by(id: params[:event_id])
        return render json: { error: "イベントが見つかりません" }, status: :not_found unless event
        return render json: { error: "試合ページの HTML がありません" }, status: :unprocessable_entity if params[:html].blank?
        return render json: { error: "試合ページの HTML が大きすぎます" }, status: :content_too_large if params[:html].to_s.bytesize > MAX_HTML_BYTES

        parsed = parse_page
        names = ::Vsmobile::MatchPageParser.player_names(parsed)
        unless names.include?(current_user.nickname)
          raise NicknameMismatchError, "この試合の 4 人（#{names.join('・')}）に、あなたのニックネーム「#{current_user.nickname}」がありません。" \
                                       "アプリのニックネームを VS.モバイルの名前と同じにしてください。"
        end

        result = ::Vsmobile::MatchImporter.new(event: event, parsed: parsed, submitted_by: current_user).import!
        EventStatsFollowUp.call(event) if result.status == :imported

        coverage = ::Vsmobile::Coverage.new(event: event)
        render json: {
          status: result.status,
          match_number: coverage.number_of(result.match),
          covered: coverage.covered_count,
          total: coverage.total,
          remaining: coverage.total - coverage.covered_count
        }
      rescue ::Vsmobile::MatchPageParser::ParseError, ::Vsmobile::MatchImporter::NoMatchError, NicknameMismatchError, ActiveRecord::RecordInvalid => e
        # 届いた HTML を取り込めなかった。参加者のブラウザで起きたことは管理者が再現できないので、何が届いたかを残す
        VsmobileParseFailure.record(user: current_user, event: event, match_ts: Integer(params[:match_ts], exception: false), error: e,
                                    request_params: params.permit(:result_self, :self_name, :time, :game_date, :shop_name).to_h, html: params[:html])
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      # scrape.py の出力と同じ形にそろえる（match_ts・time・game_date・shop_name は対戦履歴の一覧から、残りはページの解析から）
      def parse_page
        page = ::Vsmobile::MatchPageParser.new(params[:html], result_self: params[:result_self].presence, self_name: params[:self_name].presence).call
        {
          "match_ts" => Integer(params[:match_ts], exception: false),
          "time" => params[:time].presence,
          "game_date" => params[:game_date].presence,
          "shop_name" => params[:shop_name].presence
        }.merge(page)
      end
    end
  end
end
