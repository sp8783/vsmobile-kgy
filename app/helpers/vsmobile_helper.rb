# VS.モバイル連携（ブックマークレット）の表示まわり
module VsmobileHelper
  BOOKMARK_NAME = "KGY 戦績送信".freeze

  # ブックマークに登録する URL。中身は「このサイトから収集スクリプト（public/vsm/collect.js）を 1 本読み込む」だけで、
  # 本人用の鍵（k=）を付ける。収集や送信の本体はサーバー側のスクリプトにあるので、直しても配り直さなくてよい
  def vsmobile_bookmarklet(user)
    script_url = "#{request.base_url}/vsm/collect.js?k=#{user.vsmobile_token}"
    "javascript:(function(){var s=document.createElement('script');s.src='#{script_url}&t='+Date.now();document.body.appendChild(s)})()"
  end

  def vsmobile_bookmark_name
    BOOKMARK_NAME
  end
end
