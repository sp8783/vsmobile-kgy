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

# Full mobile suits database from EXVS2IB
# NOTE: When new mobile suits are added via the app or CSV import,
#       please manually update this file to keep it in sync.
mobile_suits_data = [
  { name: 'フルアーマーZZガンダム', series: '機動戦士ガンダムZZ', cost: 3000, position: 0 },
  { name: 'キュベレイ', series: '機動戦士ガンダムZZ', cost: 3000, position: 1 },
  { name: 'νガンダム', series: '機動戦士ガンダム 逆襲のシャア', cost: 3000, position: 2 },
  { name: 'サザビー', series: '機動戦士ガンダム 逆襲のシャア', cost: 3000, position: 3 },
  { name: 'V2ガンダム', series: '機動戦士Vガンダム', cost: 3000, position: 4 },
  { name: 'フルアーマー・ユニコーンガンダム', series: '機動戦士ガンダムUC', cost: 3000, position: 5 },
  { name: 'ユニコーンガンダム', series: '機動戦士ガンダムUC', cost: 3000, position: 6 },
  { name: 'バンシィ・ノルン', series: '機動戦士ガンダムUC', cost: 3000, position: 7 },
  { name: 'シナンジュ', series: '機動戦士ガンダムUC', cost: 3000, position: 8 },
  { name: 'Ex-Sガンダム', series: 'ガンダム・センチネル', cost: 3000, position: 9 },
  { name: 'νガンダムHWS', series: '機動戦士ガンダム 逆襲のシャア MSV', cost: 3000, position: 10 },
  { name: 'Hi-νガンダム', series: '機動戦士ガンダム 逆襲のシャア ベルトーチカ・チルドレン', cost: 3000, position: 11 },
  { name: 'ナイチンゲール', series: '機動戦士ガンダム 逆襲のシャア ベルトーチカ・チルドレン', cost: 3000, position: 12 },
  { name: 'RX-93ff νガンダム', series: 'THE-LIFE-SIZED νGUNDAM STATUE', cost: 3000, position: 13 },
  { name: 'Ξガンダム', series: '機動戦士ガンダム 閃光のハサウェイ', cost: 3000, position: 14 },
  { name: 'ペーネロペー', series: '機動戦士ガンダム 閃光のハサウェイ', cost: 3000, position: 15 },
  { name: 'クロスボーン・ガンダムX1フルクロス', series: '機動戦士クロスボーン・ガンダム', cost: 3000, position: 16 },
  { name: 'ゴッドガンダム', series: '機動武闘伝Gガンダム', cost: 3000, position: 17 },
  { name: 'マスターガンダム', series: '機動武闘伝Gガンダム', cost: 3000, position: 18 },
  { name: 'ウイングガンダムゼロ', series: '新機動戦記ガンダムW', cost: 3000, position: 19 },
  { name: 'ガンダムエピオン', series: '新機動戦記ガンダムW', cost: 3000, position: 20 },
  { name: 'ウイングガンダムゼロ(EW版)', series: '新機動戦記ガンダムW Endless Waltz', cost: 3000, position: 21 },
  { name: 'トールギスIII', series: '新機動戦記ガンダムW Endless Waltz', cost: 3000, position: 22 },
  { name: 'ガンダムDX', series: '機動新世紀ガンダムX', cost: 3000, position: 23 },
  { name: 'ガンダムヴァサーゴ・チェストブレイク', series: '機動新世紀ガンダムX', cost: 3000, position: 24 },
  { name: '∀ガンダム', series: '∀ガンダム', cost: 3000, position: 25 },
  { name: 'ターンX', series: '∀ガンダム', cost: 3000, position: 26 },
  { name: 'デスティニーガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 3000, position: 27 },
  { name: 'ストライクフリーダムガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 3000, position: 28 },
  { name: 'インフィニットジャスティスガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 3000, position: 29 },
  { name: 'マイティーストライクフリーダムガンダム', series: '機動戦士ガンダムSEED FREEDOM', cost: 3000, position: 30 },
  { name: 'インフィニットジャスティスガンダム弐式', series: '機動戦士ガンダムSEED FREEDOM', cost: 3000, position: 31 },
  { name: 'ダブルオーガンダム', series: '機動戦士ガンダム00', cost: 3000, position: 32 },
  { name: 'リボーンズガンダム', series: '機動戦士ガンダム00', cost: 3000, position: 33 },
  { name: 'ダブルオークアンタ', series: '劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-', cost: 3000, position: 34 },
  { name: 'ガンダムサバーニャ', series: '劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-', cost: 3000, position: 35 },
  { name: 'ガンダムハルート', series: '劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-', cost: 3000, position: 36 },
  { name: 'ダブルオークアンタ フルセイバー', series: '機動戦士ガンダム00V', cost: 3000, position: 37 },
  { name: 'ダブルオーガンダム セブンソード／G', series: '機動戦士ガンダム00V', cost: 3000, position: 38 },
  { name: 'ヤークトアルケーガンダム', series: '機動戦士ガンダム00V', cost: 3000, position: 39 },
  { name: 'ガンダムAGE-FX', series: '機動戦士ガンダムAGE', cost: 3000, position: 40 },
  { name: 'ガンダムAGE-2 ダークハウンド', series: '機動戦士ガンダムAGE', cost: 3000, position: 41 },
  { name: 'ガンダムレギルス', series: '機動戦士ガンダムAGE', cost: 3000, position: 42 },
  { name: 'G-セルフ(パーフェクトパック)', series: 'ガンダム Gのレコンギスタ', cost: 3000, position: 43 },
  { name: 'カバカーリー', series: 'ガンダム Gのレコンギスタ', cost: 3000, position: 44 },
  { name: 'ガンダム・バルバトスルプスレクス', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 3000, position: 45 },
  { name: 'ガンダム・バエル', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 3000, position: 46 },
  { name: 'ガンダム・キマリスヴィダール', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 3000, position: 47 },
  { name: 'スタービルドストライクガンダム', series: 'ガンダムビルドファイターズ', cost: 3000, position: 48 },
  { name: 'ホットスクランブルガンダム', series: 'ガンダムビルドファイターズA-R', cost: 3000, position: 49 },
  { name: 'ガンダムダブルオースカイ', series: 'ガンダムビルドダイバーズ', cost: 3000, position: 50 },
  { name: 'エクストリームガンダム type-レオスII Vs.', series: 'ガンダムEXA', cost: 3000, position: 51 },
  { name: 'N-EXTREMEガンダム エクスプロージョン', series: 'Project N-EXTREME', cost: 3000, position: 52 },
  { name: 'ジオング', series: '機動戦士ガンダム', cost: 2500, position: 53 },
  { name: 'Zガンダム', series: '機動戦士Zガンダム', cost: 2500, position: 54 },
  { name: '百式', series: '機動戦士Zガンダム', cost: 2500, position: 55 },
  { name: 'ジ・O', series: '機動戦士Zガンダム', cost: 2500, position: 56 },
  { name: 'バウンド・ドック', series: '機動戦士Zガンダム', cost: 2500, position: 57 },
  { name: 'ハンブラビ', series: '機動戦士Zガンダム', cost: 2500, position: 58 },
  { name: 'ZZガンダム', series: '機動戦士ガンダムZZ', cost: 2500, position: 59 },
  { name: 'ガンダムF91', series: '機動戦士ガンダムF91', cost: 2500, position: 60 },
  { name: 'ゴトラタン', series: '機動戦士Vガンダム', cost: 2500, position: 61 },
  { name: 'リグ・コンティオ', series: '機動戦士Vガンダム', cost: 2500, position: 62 },
  { name: 'バンシィ', series: '機動戦士ガンダムUC', cost: 2500, position: 63 },
  { name: 'ユニコーンガンダム3号機フェネクス', series: '機動戦士ガンダムNT', cost: 2500, position: 64 },
  { name: 'トーリスリッター', series: '機動戦士ガンダム外伝 ミッシングリンク', cost: 2500, position: 65 },
  { name: 'ガンダム試作2号機', series: '機動戦士ガンダム0083 STARDUST MEMORY', cost: 2500, position: 66 },
  { name: 'ガンダム試作3号機', series: '機動戦士ガンダム0083 STARDUST MEMORY', cost: 2500, position: 67 },
  { name: 'オーヴェロン', series: '機動戦士ガンダム ヴァルプルギス', cost: 2500, position: 68 },
  { name: 'クロスボーン・ガンダムX3', series: '機動戦士クロスボーン・ガンダム', cost: 2500, position: 69 },
  { name: 'クロスボーン・ガンダムX1改', series: '機動戦士クロスボーン・ガンダム', cost: 2500, position: 70 },
  { name: 'クロスボーン・ガンダムX2改', series: '機動戦士クロスボーン・ガンダム', cost: 2500, position: 71 },
  { name: 'ファントムガンダム', series: '機動戦士クロスボーン・ガンダム', cost: 2500, position: 72 },
  { name: 'ビギナ・ギナII(木星決戦仕様)', series: '機動戦士クロスボーン・ガンダム', cost: 2500, position: 73 },
  { name: 'ガンダムシュピーゲル', series: '機動武闘伝Gガンダム', cost: 2500, position: 74 },
  { name: 'アルトロンガンダム', series: '新機動戦記ガンダムW', cost: 2500, position: 75 },
  { name: 'トールギスII', series: '新機動戦記ガンダムW', cost: 2500, position: 76 },
  { name: 'トールギス', series: '新機動戦記ガンダムW', cost: 2500, position: 77 },
  { name: 'ガンダムデスサイズヘル(EW版)', series: '新機動戦記ガンダムW Endless Waltz', cost: 2500, position: 78 },
  { name: 'ガンダムヘビーアームズ改(EW版)', series: '新機動戦記ガンダムW Endless Waltz', cost: 2500, position: 79 },
  { name: 'ガンダムXディバイダー', series: '機動新世紀ガンダムX', cost: 2500, position: 80 },
  { name: 'ゴールドスモー', series: '∀ガンダム', cost: 2500, position: 81 },
  { name: 'フリーダムガンダム', series: '機動戦士ガンダムSEED', cost: 2500, position: 82 },
  { name: 'ジャスティスガンダム', series: '機動戦士ガンダムSEED', cost: 2500, position: 83 },
  { name: 'パーフェクトストライクガンダム', series: '機動戦士ガンダムSEED', cost: 2500, position: 84 },
  { name: 'プロヴィデンスガンダム', series: '機動戦士ガンダムSEED', cost: 2500, position: 85 },
  { name: 'レジェンドガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 2500, position: 86 },
  { name: 'アカツキ', series: '機動戦士ガンダムSEED DESTINY', cost: 2500, position: 87 },
  { name: 'インパルスガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 2500, position: 88 },
  { name: 'デスティニーガンダム(ハイネ機)', series: '機動戦士ガンダムSEED DESTINY', cost: 2500, position: 89 },
  { name: 'ストライクノワール', series: '機動戦士ガンダムSEED C.E.73 STARGAZER', cost: 2500, position: 90 },
  { name: 'ライジングフリーダムガンダム', series: '機動戦士ガンダムSEED FREEDOM', cost: 2500, position: 91 },
  { name: 'アストレイレッドフレーム改', series: '機動戦士ガンダムSEED ASTRAY', cost: 2500, position: 92 },
  { name: 'アストレイレッドフレーム（レッドドラゴン）', series: '機動戦士ガンダムSEED ASTRAY', cost: 2500, position: 93 },
  { name: 'アストレイブルーフレームD', series: '機動戦士ガンダムSEED ASTRAY', cost: 2500, position: 94 },
  { name: 'アストレイゴールドフレーム天ミナ', series: '機動戦士ガンダムSEED ASTRAY', cost: 2500, position: 95 },
  { name: 'ドレッドノートイータ', series: '機動戦士ガンダムSEED ASTRAY', cost: 2500, position: 96 },
  { name: 'ケルディムガンダム', series: '機動戦士ガンダム00', cost: 2500, position: 97 },
  { name: 'アリオスガンダム', series: '機動戦士ガンダム00', cost: 2500, position: 98 },
  { name: 'アルケーガンダム', series: '機動戦士ガンダム00', cost: 2500, position: 99 },
  { name: 'スサノオ', series: '機動戦士ガンダム00', cost: 2500, position: 100 },
  { name: 'ラファエルガンダム', series: '劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-', cost: 2500, position: 101 },
  { name: 'ブレイヴ指揮官用試験機', series: '劇場版 機動戦士ガンダム00 -A wakening of the Trailblazer-', cost: 2500, position: 102 },
  { name: 'アヴァランチエクシア', series: '機動戦士ガンダム00V', cost: 2500, position: 103 },
  { name: 'ガンダムAGE-2', series: '機動戦士ガンダムAGE', cost: 2500, position: 104 },
  { name: 'ガンダムAGE-3', series: '機動戦士ガンダムAGE', cost: 2500, position: 105 },
  { name: 'ガンダムAGE-1 フルグランサ', series: '機動戦士ガンダムAGE', cost: 2500, position: 106 },
  { name: 'ゼイドラ', series: '機動戦士ガンダムAGE', cost: 2500, position: 107 },
  { name: 'フォーンファルシア', series: '機動戦士ガンダムAGE', cost: 2500, position: 108 },
  { name: 'G-セルフ', series: 'ガンダム Gのレコンギスタ', cost: 2500, position: 109 },
  { name: 'ダハック', series: 'ガンダム Gのレコンギスタ', cost: 2500, position: 110 },
  { name: 'ガンダム・バルバトスルプス', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 2500, position: 111 },
  { name: 'ガンダム・グシオンリベイクフルシティ', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 2500, position: 112 },
  { name: 'アトラスガンダム', series: '機動戦士ガンダム サンダーボルト', cost: 2500, position: 113 },
  { name: 'フルアーマー・ガンダム', series: '機動戦士ガンダム サンダーボルト', cost: 2500, position: 114 },
  { name: 'サイコ・ザク', series: '機動戦士ガンダム サンダーボルト', cost: 2500, position: 115 },
  { name: 'ガンダム・エアリアル(改修型)', series: '機動戦士ガンダム 水星の魔女', cost: 2500, position: 116 },
  { name: 'ガンダム・エアリアル(改修型)パーメットスコア・エイト', series: '機動戦士ガンダム 水星の魔女', cost: 2500, position: 117 },
  { name: 'ダリルバルデ', series: '機動戦士ガンダム 水星の魔女', cost: 2500, position: 118 },
  { name: 'GQuuuuuuX', series: '機動戦士Gundam GQuuuuuuX', cost: 2500, position: 119 },
  { name: 'ウイングガンダムフェニーチェ', series: 'ガンダムビルドファイターズ', cost: 2500, position: 120 },
  { name: '戦国アストレイ頑駄無', series: 'ガンダムビルドファイターズ', cost: 2500, position: 121 },
  { name: 'キュベレイパピヨン', series: 'ガンダムビルドファイターズ', cost: 2500, position: 122 },
  { name: 'トライバーニングガンダム', series: 'ガンダムビルドファイターズトライ', cost: 2500, position: 123 },
  { name: 'ライトニングガンダムフルバーニアン', series: 'ガンダムビルドファイターズトライ', cost: 2500, position: 124 },
  { name: 'スターウイニングガンダム', series: 'ガンダムビルドファイターズトライ', cost: 2500, position: 125 },
  { name: 'トランジェントガンダム', series: 'ガンダムビルドファイターズトライ', cost: 2500, position: 126 },
  { name: 'RX-零丸', series: 'ガンダムビルドダイバーズ', cost: 2500, position: 127 },
  { name: 'アースリィガンダム', series: 'ガンダムビルドダイバーズRe:RISE', cost: 2500, position: 128 },
  { name: '騎士ガンダム', series: 'SDガンダム外伝', cost: 2500, position: 129 },
  { name: 'エクストリームガンダム エクリプス-F', series: 'ガンダムEXA', cost: 2500, position: 130 },
  { name: 'エクストリームガンダム ゼノン-F', series: 'ガンダムEXA', cost: 2500, position: 131 },
  { name: 'エクストリームガンダム アイオス-F', series: 'ガンダムEXA', cost: 2500, position: 132 },
  { name: 'エクストリームガンダム エクセリア', series: 'ガンダムEXA', cost: 2500, position: 133 },
  { name: 'N-EXTREMEガンダム ヴィシャス', series: 'Project N-EXTREME', cost: 2500, position: 134 },
  { name: 'ガンダム', series: '機動戦士ガンダム', cost: 2000, position: 135 },
  { name: 'ガンダム(Gメカ)', series: '機動戦士ガンダム', cost: 2000, position: 136 },
  { name: 'シャア専用ゲルググ', series: '機動戦士ガンダム', cost: 2000, position: 137 },
  { name: 'ギャン', series: '機動戦士ガンダム', cost: 2000, position: 138 },
  { name: 'ディジェ', series: '機動戦士Zガンダム', cost: 2000, position: 139 },
  { name: 'ガンダムMk-II', series: '機動戦士Zガンダム', cost: 2000, position: 140 },
  { name: 'メッサーラ', series: '機動戦士Zガンダム', cost: 2000, position: 141 },
  { name: 'ガブスレイ', series: '機動戦士Zガンダム', cost: 2000, position: 142 },
  { name: 'マラサイ', series: '機動戦士Zガンダム', cost: 2000, position: 143 },
  { name: 'ギャプラン', series: '機動戦士Zガンダム', cost: 2000, position: 144 },
  { name: 'キュベレイMk-II(プル)', series: '機動戦士ガンダムZZ', cost: 2000, position: 145 },
  { name: 'ザクIII改', series: '機動戦士ガンダムZZ', cost: 2000, position: 146 },
  { name: 'ドーベン・ウルフ', series: '機動戦士ガンダムZZ', cost: 2000, position: 147 },
  { name: 'アッガイ(ハマーン搭乗)', series: '機動戦士ガンダムZZ', cost: 2000, position: 148 },
  { name: 'Zガンダム(ルー搭乗)', series: '機動戦士ガンダムZZ', cost: 2000, position: 149 },
  { name: 'ヤクト・ドーガ', series: '機動戦士ガンダム 逆襲のシャア', cost: 2000, position: 150 },
  { name: 'ヴィクトリーガンダム', series: '機動戦士Vガンダム', cost: 2000, position: 151 },
  { name: 'ゲドラフ', series: '機動戦士Vガンダム', cost: 2000, position: 152 },
  { name: 'デルタプラス', series: '機動戦士ガンダムUC', cost: 2000, position: 153 },
  { name: 'クシャトリヤ', series: '機動戦士ガンダムUC', cost: 2000, position: 154 },
  { name: 'ローゼン・ズール', series: '機動戦士ガンダムUC', cost: 2000, position: 155 },
  { name: 'ナラティブガンダム', series: '機動戦士ガンダムNT', cost: 2000, position: 156 },
  { name: 'シナンジュ・スタイン', series: '機動戦士ガンダムNT', cost: 2000, position: 157 },
  { name: '高機動型ザクII後期型(ジョニー・ライデン機)', series: '機動戦士ガンダムMSV', cost: 2000, position: 158 },
  { name: '高機動型ザクII改(シン・マツナガ機)', series: '機動戦士ガンダムMSV', cost: 2000, position: 159 },
  { name: 'ブルーディスティニー1号機', series: '機動戦士ガンダム外伝 THE BLUE DESTINY', cost: 2000, position: 160 },
  { name: 'ペイルライダー(陸戦重装仕様)', series: '機動戦士ガンダム外伝 ミッシングリンク', cost: 2000, position: 161 },
  { name: '高機動型ゲルググ(ヴィンセント機)', series: '機動戦士ガンダム外伝 ミッシングリンク', cost: 2000, position: 162 },
  { name: 'イフリート(シュナイド機)', series: '機動戦士ガンダム外伝 ミッシングリンク', cost: 2000, position: 163 },
  { name: 'ガンダム試作1号機フルバーニアン', series: '機動戦士ガンダム0083 STARDUST MEMORY', cost: 2000, position: 164 },
  { name: 'ガーベラ・テトラ', series: '機動戦士ガンダム0083 STARDUST MEMORY', cost: 2000, position: 165 },
  { name: 'シャイニングガンダム', series: '機動武闘伝Gガンダム', cost: 2000, position: 166 },
  { name: 'ドラゴンガンダム', series: '機動武闘伝Gガンダム', cost: 2000, position: 167 },
  { name: 'ガンダムマックスター', series: '機動武闘伝Gガンダム', cost: 2000, position: 168 },
  { name: 'ノーベルガンダム', series: '機動武闘伝Gガンダム', cost: 2000, position: 169 },
  { name: 'ウイングガンダム', series: '新機動戦記ガンダムW', cost: 2000, position: 170 },
  { name: 'ガンダムデスサイズヘル', series: '新機動戦記ガンダムW', cost: 2000, position: 171 },
  { name: 'ガンダムヘビーアームズ改', series: '新機動戦記ガンダムW', cost: 2000, position: 172 },
  { name: 'ガンダムサンドロック改', series: '新機動戦記ガンダムW', cost: 2000, position: 173 },
  { name: 'ガンダムX', series: '機動新世紀ガンダムX', cost: 2000, position: 174 },
  { name: 'ベルティゴ', series: '機動新世紀ガンダムX', cost: 2000, position: 175 },
  { name: 'コレンカプル', series: '∀ガンダム', cost: 2000, position: 176 },
  { name: 'ストライクガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 177 },
  { name: 'イージスガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 178 },
  { name: 'ブリッツガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 179 },
  { name: 'カラミティガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 180 },
  { name: 'フォビドゥンガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 181 },
  { name: 'レイダーガンダム', series: '機動戦士ガンダムSEED', cost: 2000, position: 182 },
  { name: 'インパルスガンダム(ルナマリア搭乗)', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 183 },
  { name: 'グフイグナイテッド', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 184 },
  { name: 'ストライクルージュ(オオトリ装備)', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 185 },
  { name: 'ガナーザクウォーリア', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 186 },
  { name: 'ガイアガンダム', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 187 },
  { name: 'インフィニットジャスティスガンダム(ラクス搭乗)', series: '機動戦士ガンダムSEED DESTINY', cost: 2000, position: 188 },
  { name: 'スターゲイザー', series: '機動戦士ガンダムSEED C.E.73 STARGAZER', cost: 2000, position: 189 },
  { name: 'アストレイレッドフレーム', series: '機動戦士ガンダムSEED ASTRAY', cost: 2000, position: 190 },
  { name: 'ドレッドノートガンダム(Xアストレイ)', series: '機動戦士ガンダムSEED ASTRAY', cost: 2000, position: 191 },
  { name: 'アストレイブルーフレームセカンドL', series: '機動戦士ガンダムSEED ASTRAY', cost: 2000, position: 192 },
  { name: 'アストレイゴールドフレーム天', series: '機動戦士ガンダムSEED ASTRAY', cost: 2000, position: 193 },
  { name: 'ハイペリオンガンダム', series: '機動戦士ガンダムSEED ASTRAY', cost: 2000, position: 194 },
  { name: 'ガンダムエクシア', series: '機動戦士ガンダム00', cost: 2000, position: 195 },
  { name: 'ガンダムデュナメス', series: '機動戦士ガンダム00', cost: 2000, position: 196 },
  { name: 'ガンダムキュリオス', series: '機動戦士ガンダム00', cost: 2000, position: 197 },
  { name: 'ガンダムヴァーチェ', series: '機動戦士ガンダム00', cost: 2000, position: 198 },
  { name: 'ガンダムスローネツヴァイ', series: '機動戦士ガンダム00', cost: 2000, position: 199 },
  { name: 'ガンダムスローネドライ', series: '機動戦士ガンダム00', cost: 2000, position: 200 },
  { name: 'ガラッゾ(ヒリング・ケア機)', series: '機動戦士ガンダム00', cost: 2000, position: 201 },
  { name: 'グラハム専用ユニオンフラッグカスタム', series: '機動戦士ガンダム00', cost: 2000, position: 202 },
  { name: 'ガンダムAGE-1', series: '機動戦士ガンダムAGE', cost: 2000, position: 203 },
  { name: 'ファルシア', series: '機動戦士ガンダムAGE', cost: 2000, position: 204 },
  { name: 'G-アルケイン(フルドレス)', series: 'ガンダム Gのレコンギスタ', cost: 2000, position: 205 },
  { name: 'マックナイフ(マスク機)', series: 'ガンダム Gのレコンギスタ', cost: 2000, position: 206 },
  { name: 'モンテーロ', series: 'ガンダム Gのレコンギスタ', cost: 2000, position: 207 },
  { name: 'ヘカテー', series: 'ガンダム Gのレコンギスタ', cost: 2000, position: 208 },
  { name: 'ガンダム・フラウロス', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 2000, position: 209 },
  { name: 'ガンダム・バルバトス', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 2000, position: 210 },
  { name: 'ガンダム・キマリストルーパー', series: '機動戦士ガンダム 鉄血のオルフェンズ', cost: 2000, position: 211 },
  { name: 'アッガイ(ダリル搭乗)', series: '機動戦士ガンダム サンダーボルト', cost: 2000, position: 212 },
  { name: 'ガンダム・エアリアル', series: '機動戦士ガンダム 水星の魔女', cost: 2000, position: 213 },
  { name: 'ガンダム・ファラクト', series: '機動戦士ガンダム 水星の魔女', cost: 2000, position: 214 },
  { name: '赤いガンダム', series: '機動戦士Gundam GQuuuuuuX', cost: 2000, position: 215 },
  { name: 'ビルドストライクガンダム(フルパッケージ)', series: 'ガンダムビルドファイターズ', cost: 2000, position: 216 },
  { name: 'ガンダムX魔王', series: 'ガンダムビルドファイターズ', cost: 2000, position: 217 },
  { name: 'ザクアメイジング', series: 'ガンダムビルドファイターズ', cost: 2000, position: 218 },
  { name: 'ガンダムダブルオーダイバーエース', series: 'ガンダムビルドダイバーズ', cost: 2000, position: 219 },
  { name: 'N-EXTREMEガンダム ザナドゥ', series: 'Project N-EXTREME', cost: 2000, position: 220 },
  { name: 'ガンキャノン', series: '機動戦士ガンダム', cost: 1500, position: 221 },
  { name: 'シャア専用ザクII', series: '機動戦士ガンダム', cost: 1500, position: 222 },
  { name: 'ザクII(ドアン機)', series: '機動戦士ガンダム', cost: 1500, position: 223 },
  { name: 'アッガイ', series: '機動戦士ガンダム', cost: 1500, position: 224 },
  { name: 'キュベレイMk-II(プルツー)', series: '機動戦士ガンダムZZ', cost: 1500, position: 225 },
  { name: 'リ・ガズィ', series: '機動戦士ガンダム 逆襲のシャア', cost: 1500, position: 226 },
  { name: 'ベルガ・ギロス', series: '機動戦士ガンダムF91', cost: 1500, position: 227 },
  { name: 'ガンイージ', series: '機動戦士Vガンダム', cost: 1500, position: 228 },
  { name: 'アレックス', series: '機動戦士ガンダム0080 ポケットの中の戦争', cost: 1500, position: 229 },
  { name: 'ザクII改', series: '機動戦士ガンダム0080 ポケットの中の戦争', cost: 1500, position: 230 },
  { name: 'ケンプファー', series: '機動戦士ガンダム0080 ポケットの中の戦争', cost: 1500, position: 231 },
  { name: 'ガンダムEz8', series: '機動戦士ガンダム 第08MS小隊', cost: 1500, position: 232 },
  { name: 'グフ・カスタム', series: '機動戦士ガンダム 第08MS小隊', cost: 1500, position: 233 },
  { name: 'ヅダ', series: '機動戦士ガンダム MS IGLOO', cost: 1500, position: 234 },
  { name: 'ヒルドルブ', series: '機動戦士ガンダム MS IGLOO', cost: 1500, position: 235 },
  { name: 'イフリート改', series: '機動戦士ガンダム外伝 THE BLUE DESTINY', cost: 1500, position: 236 },
  { name: 'ライジングガンダム', series: '機動武闘伝Gガンダム', cost: 1500, position: 237 },
  { name: 'カプル', series: '∀ガンダム', cost: 1500, position: 238 },
  { name: 'バスターガンダム', series: '機動戦士ガンダムSEED', cost: 1500, position: 239 },
  { name: 'デュエルガンダムアサルトシュラウド', series: '機動戦士ガンダムSEED', cost: 1500, position: 240 },
  { name: 'ラゴゥ', series: '機動戦士ガンダムSEED', cost: 1500, position: 241 },
  { name: 'ティエレンタオツー', series: '機動戦士ガンダム00', cost: 1500, position: 242 },
  { name: 'アヘッド脳量子波対応型(スマルトロン)', series: '機動戦士ガンダム00', cost: 1500, position: 243 },
  { name: 'G-ルシファー', series: 'ガンダム Gのレコンギスタ', cost: 1500, position: 244 },
  { name: 'N-EXTREMEガンダム スプレマシー', series: 'Project N-EXTREME', cost: 1500, position: 245 }
]

mobile_suits_data.each do |suit_data|
  suit = MobileSuit.find_or_create_by!(name: suit_data[:name]) do |suit|
    suit.series = suit_data[:series]
    suit.cost = suit_data[:cost]
    suit.position = suit_data[:position]
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
