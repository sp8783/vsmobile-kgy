# バージョンごとのリリース告知の記録。同じバージョンを二重に告知しないために使う
class ReleaseAnnouncement < ApplicationRecord
  belongs_to :announcement, optional: true

  validates :version, presence: true, uniqueness: true
end
