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

# Guest user
guest = User.find_or_create_by!(username: 'guest') do |user|
  user.nickname = 'ゲスト'
  user.password = 'guestpassword'
  user.password_confirmation = 'guestpassword'
  user.is_admin = false
  user.is_guest = true
  user.notification_enabled = false
end
puts "  Created guest user: #{guest.username}"

puts "\nCreating mobile suits..."

# 機体マスタは db/data/units.json を単一の情報源とする。unitNo の昇順を position に採用。
units = JSON.parse(Rails.root.join('db/data/units.json').read)['units']

upserted = 0
units.each.with_index(1) do |unit, idx|
  # name は半角/全角カッコ表記揺れがあり得るため両方向で既存レコードを探す
  fullwidth_name = unit['name'].tr('()', '（）')
  suit = MobileSuit.find_by(name: unit['name']) ||
         MobileSuit.find_by(name: fullwidth_name) ||
         MobileSuit.new

  suit.assign_attributes(
    name: unit['name'],
    series: unit['series'],
    cost: unit['cost'].to_i,
    position: idx
  )
  suit.save!
  upserted += 1
end
puts "  Upserted #{upserted} mobile suits"

puts "\nCreating master emojis..."

master_emojis_data = [
  # Unicode絵文字
  { name: 'いいね', image_key: "👍", position: 1 },
  { name: '熱い試合', image_key: "🔥", position: 2 },
  { name: 'ナイス', image_key: "👏", position: 3 },
  { name: 'すごい', image_key: "🎉", position: 4 },
  { name: '？', image_key: "❓", position: 5 },
  { name: '怒り', image_key: "😡", position: 6 },
  { name: 'ボム', image_key: "💣", position: 7 },
  { name: 'うんち', image_key: "💩", position: 8 },
  { name: 'サル', image_key: "🐒", position: 9 },
  { name: 'エビ', image_key: "🦐", position: 10 },
  # カスタム画像絵文字
  { name: 'GG', image_key: 'gg.png', position: 11 },
  { name: '激アツ', image_key: 'gekiatsu.gif', position: 12 },
  { name: 'イニブ', image_key: 'inibu.gif', position: 13 },
  { name: 'ガチキャリー', image_key: 'gachicarry.png', position: 14 },
  { name: 'RTA', image_key: 'RTA.png', position: 15 },
  { name: 'ガチ戦', image_key: 'gachisen.png', position: 16 },
  { name: 'えらいえらい', image_key: 'eraierai.png', position: 17 },
  { name: '助かりました', image_key: 'tasukarimashita.png', position: 18 },
  { name: '相方最強', image_key: 'aikatasaikyo.png', position: 19 },
  { name: 'きちゃ', image_key: 'kitya.png', position: 20 },
  { name: 'やりこみ', image_key: 'yarikomi.png', position: 21 },
  { name: '若い', image_key: 'wakai.png', position: 22 },
  { name: 'ごめんなさい', image_key: 'gomennasai.png', position: 23 },
  { name: 'もう持ちません', image_key: 'moumotimasen.png', position: 24 },
  { name: '前に出ない', image_key: 'maenidenai.png', position: 25 },
  { name: '引退です', image_key: 'intaidesu.png', position: 26 },
  { name: '出禁', image_key: 'dekin.png', position: 27 },
  { name: '撃破されました', image_key: 'gekihasaremashita.png', position: 28 },
  { name: '損傷なし', image_key: 'sonshonashi.png', position: 29 },
  { name: '損傷軽微', image_key: 'sonshokeibi.png', position: 30 },
  { name: '損傷拡大', image_key: 'sonshokakudai.png', position: 31 },
  { name: '損傷甚大', image_key: 'sonshojindai.png', position: 32 },
  { name: '叫び', image_key: 'face-fuchsia-tongue-out.png', position: 33 }
]

master_emojis_data.each do |emoji_data|
  emoji = MasterEmoji.find_or_create_by!(name: emoji_data[:name]) do |emoji|
    emoji.image_key = emoji_data[:image_key]
    emoji.position = emoji_data[:position]
    emoji.is_active = true
  end
  puts "  Created master emoji: #{emoji.name} (#{emoji.image_key})"
end

puts "\nSeed data created successfully!"
puts "  Users: #{User.count}"
puts "  Mobile Suits: #{MobileSuit.count}"
puts "  Master Emojis: #{MasterEmoji.count}"
