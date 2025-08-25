# ユーザー
user1 = User.create!(name: "アムロ", email: "amuro@example.com", password: "password")
user2 = User.create!(name: "シャア", email: "char@example.com", password: "password")
user3 = User.create!(name: "カミーユ", email: "kamille@example.com", password: "password")
user4 = User.create!(name: "ジュドー", email: "judo@example.com", password: "password")

# 機体
ms1 = MobileSuit.create!(name: "νガンダム", cost: 3000, series: "U.C.")
ms2 = MobileSuit.create!(name: "サザビー", cost: 3000, series: "U.C.")

# チーム
team1 = Team.create!(player1: user1, player2: user2, name: "連邦")
team2 = Team.create!(player1: user3, player2: user4, name: "エゥーゴ")

# イベント
event = Event.create!(name: "貸切対戦会", date: Date.today, start_time: Time.now, end_time: Time.now + 3.hours, event_type: "オフライン", location: "秋葉原", notes: "初回イベント")

# 試合
match = Match.create!(event: event, team1: team1, team2: team2, winner_team: team1)

# 試合参加者
MatchPlayer.create!(match: match, player: user1, team: team1, mobile_suit: ms1)
MatchPlayer.create!(match: match, player: user2, team: team1, mobile_suit: ms2)
MatchPlayer.create!(match: match, player: user3, team: team2, mobile_suit: ms1)
MatchPlayer.create!(match: match, player: user4, team: team2, mobile_suit: ms2)
