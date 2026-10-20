require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "Discord フォーラムスレッド URL からスレッドの ID を取り出す" do
    assert_equal "1490000000000000001", Event.new(discord_thread_url: "https://discord.com/channels/731348521269329971/1490000000000000001").discord_thread_id
    assert_equal "1490000000000000001", Event.new(discord_thread_url: "https://discord.com/channels/731348521269329971/1490000000000000001/1490000000000000002").discord_thread_id
  end

  test "Discord のチャンネル URL でなければスレッドの ID は nil" do
    assert_nil Event.new(discord_thread_url: nil).discord_thread_id
    assert_nil Event.new(discord_thread_url: "https://example.com/channels/1/2").discord_thread_id
  end
end
