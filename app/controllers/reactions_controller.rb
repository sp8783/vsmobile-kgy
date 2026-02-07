class ReactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match

  def toggle
    unless can_react?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash_message",
            locals: { type: "warning", message: "スタンプは一般ユーザーのみ利用できます。" })
        end
        format.html { redirect_to matches_path, alert: "スタンプは一般ユーザーのみ利用できます。" }
      end
      return
    end

    @reaction_user = viewing_as_user
    @master_emoji = MasterEmoji.find(params[:master_emoji_id])
    @reaction = @match.reactions.find_by(user: @reaction_user, master_emoji: @master_emoji)

    if @reaction
      @reaction.destroy
      @action = :removed
    else
      @match.reactions.create!(user: @reaction_user, master_emoji: @master_emoji)
      @action = :added
    end

    # アソシエーションのキャッシュをクリアして最新の状態を取得
    @match.reactions.reload

    # 他のユーザーにリアルタイムブロードキャスト
    broadcast_reaction_update

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to match_path(@match) }
    end
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def broadcast_reaction_update
    target = helpers.dom_id(@match, "reaction_#{@master_emoji.id}")

    # リクエストコンテキスト内でHTMLをレンダリング（URLヘルパー・CSRFトークンが利用可能）
    show_html = render_to_string(
      partial: "reactions/reaction_button",
      locals: { match: @match, emoji: @master_emoji, compact: false, signed_in_user: nil }
    )

    compact_html = render_to_string(
      partial: "reactions/reaction_button",
      locals: { match: @match, emoji: @master_emoji, compact: true, signed_in_user: nil }
    )

    # Show page 向けブロードキャスト
    Turbo::StreamsChannel.broadcast_replace_to(
      "match_#{@match.id}_reactions",
      target: target,
      html: show_html
    )

    # Index page 向けブロードキャスト（compact版）
    Turbo::StreamsChannel.broadcast_replace_to(
      "match_#{@match.id}_reactions_compact",
      target: target,
      html: compact_html
    )
  rescue => e
    Rails.logger.error("Reaction broadcast failed: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end
end
