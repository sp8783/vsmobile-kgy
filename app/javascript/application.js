// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// 対戦履歴ページを離れる前にフィルター付き URL を保存
document.addEventListener("turbo:before-visit", () => {
  if (window.location.pathname === "/matches") {
    sessionStorage.setItem("matchesReturnUrl", window.location.href)
  }
})
