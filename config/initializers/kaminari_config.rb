# frozen_string_literal: true

Kaminari.configure do |config|
  # 1ページあたりのアイテム数
  config.default_per_page = 25
  # config.max_per_page = nil

  # 現在のページの前後に表示するページ数
  config.window = 2

  # 最初と最後に常に表示するページ数
  config.outer_window = 1

  # 左端に常に表示するページ数
  config.left = 1

  # 右端に常に表示するページ数
  config.right = 1

  # config.page_method_name = :page
  # config.param_name = :page
  # config.max_pages = nil
  # config.params_on_first_page = false
end
