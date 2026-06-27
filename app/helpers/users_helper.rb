module UsersHelper
  # プレイヤー名の表示。ゲスト閲覧時（viewing_as_user.is_guest）は実名の代わりに
  # 安定した仮名（プレイヤーA / プレイヤーB …）を返す。同一ユーザーはアプリ全体で
  # 常に同じ仮名になる（ユーザーIDの昇順インデックスから決定）。
  # コンテンツ上のプレイヤー名表示は必ずこのヘルパーを通すこと。
  def player_name(user)
    return "" if user.nil?
    return user.nickname unless guest_view?

    "プレイヤー#{alphabetic_label(player_alias_index(user.id))}"
  end

  # ゲストとして閲覧中か（管理者の視点切替で「ゲストとして表示」した場合も含む）
  def guest_view?
    viewing_as_user&.is_guest
  end

  private

  # ユーザーIDを安定した連番インデックス（0始まり）に変換する。
  # リクエスト内でメモ化。未知IDは末尾に積む。
  def player_alias_index(user_id)
    @_player_alias_index ||= User.order(:id).pluck(:id).each_with_index.to_h
    @_player_alias_index[user_id] || (@_player_alias_index[user_id] = @_player_alias_index.size)
  end

  # 0 -> "A", 25 -> "Z", 26 -> "AA" の bijective base-26 ラベル
  def alphabetic_label(index)
    n = index + 1
    label = +""
    while n.positive?
      n, r = (n - 1).divmod(26)
      label.prepend((65 + r).chr)
    end
    label
  end
end
