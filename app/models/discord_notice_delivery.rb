# イベントごとに、どの Discord 投稿を何日前に送ったかの記録。同じ投稿を二重に送らないために使う
class DiscordNoticeDelivery < ApplicationRecord
  belongs_to :event

  validates :kind, inclusion: { in: DiscordNotice::KINDS }
  validates :days_before, uniqueness: { scope: [ :event_id, :kind ] }
end
