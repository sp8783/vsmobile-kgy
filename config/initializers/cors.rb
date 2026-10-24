# VS.モバイル連携: web.vsmobile.jp のページ上で動くブックマークレット（public/vsm/collect.js）が
# 試合データを /api/vsmobile/* に送れるようにする。許可するのはこのオリジンとこのパスだけ
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://web.vsmobile.jp"
    resource "/api/vsmobile/*", headers: :any, methods: %i[get post options], max_age: 3600
  end
end
