# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Creating users..."

# Admin user
admin = User.find_or_create_by!(username: 'admin') do |user|
  user.nickname = '管理者'
  user.password = 'password'
  user.password_confirmation = 'password'
  user.is_admin = true
  user.notification_enabled = false
end
puts "  Created admin user: #{admin.username}"

# Test users
test_users = [
  { username: 'player1', nickname: 'プレイヤー1' },
  { username: 'player2', nickname: 'プレイヤー2' },
  { username: 'player3', nickname: 'プレイヤー3' },
  { username: 'player4', nickname: 'プレイヤー4' },
  { username: 'player5', nickname: 'プレイヤー5' }
]

test_users.each do |user_data|
  user = User.find_or_create_by!(username: user_data[:username]) do |user|
    user.nickname = user_data[:nickname]
    user.password = 'password'
    user.password_confirmation = 'password'
    user.is_admin = false
    user.notification_enabled = true
  end
  puts "  Created test user: #{user.username}"
end

puts "\nCreating mobile suits..."

# Sample mobile suits from EXVS2IB with different costs
mobile_suits_data = [
  # 1000 cost
  { name: 'ザクII', series: '機動戦士ガンダム', cost: 1000 },
  { name: 'ジム', series: '機動戦士ガンダム', cost: 1000 },

  # 1500 cost
  { name: 'アッガイ', series: '機動戦士ガンダム', cost: 1500 },
  { name: 'ガンダム', series: '機動戦士ガンダム', cost: 1500 },

  # 2000 cost
  { name: 'ガンダムMk-II（エゥーゴ）', series: '機動戦士Zガンダム', cost: 2000 },
  { name: 'キュベレイ', series: '機動戦士Zガンダム', cost: 2000 },
  { name: 'バンシィ・ノルン', series: '機動戦士ガンダムUC', cost: 2000 },
  { name: 'ストライクフリーダムガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 2000 },

  # 2500 cost
  { name: 'νガンダム', series: '機動戦士ガンダム 逆襲のシャア', cost: 2500 },
  { name: 'サザビー', series: '機動戦士ガンダム 逆襲のシャア', cost: 2500 },
  { name: 'ユニコーンガンダム', series: '機動戦士ガンダムUC', cost: 2500 },
  { name: 'デスティニーガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 2500 },

  # 3000 cost
  { name: 'Hi-νガンダム', series: '機動戦士ガンダム 逆襲のシャア ベルトーチカ・チルドレン', cost: 3000 },
  { name: 'ナイチンゲール', series: '機動戦士ガンダム 逆襲のシャア ベルトーチカ・チルドレン', cost: 3000 },
  { name: 'ガンダム・バルバトスルプスレクス', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 3000 }
]

mobile_suits_data.each do |suit_data|
  suit = MobileSuit.find_or_create_by!(name: suit_data[:name]) do |suit|
    suit.series = suit_data[:series]
    suit.cost = suit_data[:cost]
  end
  puts "  Created mobile suit: #{suit.name} (#{suit.cost}コスト)"
end

puts "\nCreating test event..."

# Test event
event = Event.find_or_create_by!(name: '第1回 KGY対戦会') do |event|
  event.held_on = Date.today
  event.description = 'テストイベント'
end
puts "  Created event: #{event.name}"

puts "\nSeed data created successfully!"
puts "  Users: #{User.count}"
puts "  Mobile Suits: #{MobileSuit.count}"
puts "  Events: #{Event.count}"
