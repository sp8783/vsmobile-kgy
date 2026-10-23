require "test_helper"

# ログインの試行の回数制限（同じ IP から 3 分に 10 回まで）
class SignInRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "player_a", nickname: "太郎さん", password: "password123")
  end

  test "回数の上限までは普通にログインできる" do
    post user_session_path, params: { user: { username: "player_a", password: "password123" } }

    assert_redirected_to root_path
  end

  test "上限を超えるとログインの画面に戻し、試行が多すぎると知らせる" do
    with_attempt_count(11) do
      post user_session_path, params: { user: { username: "player_a", password: "password123" } }
    end

    assert_redirected_to new_user_session_path
    assert_equal "ログインの試行が多すぎます。しばらく待ってからやり直してください。", flash[:alert]
  end

  test "ゲストログインも同じ上限で制限する" do
    with_attempt_count(11) do
      post guest_login_path
    end

    assert_redirected_to new_user_session_path
  end

  private

  # test 環境のキャッシュは null_store で試行を数えないので、数えた回数を差し替える（minitest/mock は入っていない）
  def with_attempt_count(count)
    Rails.cache.define_singleton_method(:increment) { |*, **| count }
    yield
  ensure
    Rails.cache.singleton_class.remove_method(:increment)
  end
end
