class PushNotificationService
  class << self
    # seat_position: :seat_1 (配信台), :seat_2 (配信台の隣), :seat_3/:seat_4 (非配信台)
    def notify_match_upcoming(user:, matches_until_turn:, rotation:, current_match_number:, seat_position: nil, partner_name: nil)
      return unless user.push_notifications_enabled?

      title = "あと#{matches_until_turn}試合です【現在：第#{current_match_number}試合】"
      body = build_notification_body(seat_position, partner_name)

      SendPushNotificationJob.perform_later(
        user_id: user.id,
        title: title,
        body: body,
        path: "/dashboard"
      )
    end

    def notify_match_now(user:, rotation:, match_number:, seat_position: nil, partner_name: nil)
      return unless user.push_notifications_enabled?

      title = "出番です！【第#{match_number}試合】"
      body = build_notification_body(seat_position, partner_name)

      SendPushNotificationJob.perform_later(
        user_id: user.id,
        title: title,
        body: body,
        path: "/dashboard"
      )
    end

    def notify_timestamps_registered(event:, count:)
      User.where(is_admin: true).find_each do |user|
        next unless user.push_notifications_enabled?

        SendPushNotificationJob.perform_later(
          user_id: user.id,
          title: "タイムスタンプ登録完了",
          body: "#{event.name} の #{count} 試合分が登録されました",
          path: "/events/#{event.id}"
        )
      end
    end

    def notify_timestamps_failed(event:, error:)
      User.where(is_admin: true).find_each do |user|
        next unless user.push_notifications_enabled?

        SendPushNotificationJob.perform_later(
          user_id: user.id,
          title: "タイムスタンプ登録失敗",
          body: "#{event.name}: #{error}",
          path: "/events/#{event.id}"
        )
      end
    end

    def notify_rotation_activated(rotation:)
      player_ids = collect_player_ids(rotation)
      return if player_ids.empty?

      User.where(id: player_ids).find_each do |user|
        next unless user.push_notifications_enabled?

        SendPushNotificationJob.perform_later(
          user_id: user.id,
          title: "ローテーションが開始されました",
          body: "#{rotation.display_name}が開始されました",
          path: "/dashboard"
        )
      end
    end

    private

    def seat_display_text(seat_position)
      case seat_position
      when :seat_1
        "🔴配信台"
      when :seat_2
        "配信台の隣"
      when :seat_3, :seat_4
        "非配信台"
      else
        nil
      end
    end

    def build_notification_body(seat_position, partner_name)
      parts = []
      seat_text = seat_display_text(seat_position)
      parts << seat_text if seat_text
      parts << "パートナー: #{partner_name}" if partner_name
      parts.any? ? parts.join(" / ") : "試合の準備をしてください"
    end

    def collect_player_ids(rotation)
      rotation.rotation_matches.flat_map do |rm|
        [ rm.team1_player1_id, rm.team1_player2_id, rm.team2_player1_id, rm.team2_player2_id ]
      end.compact.uniq
    end
  end
end
