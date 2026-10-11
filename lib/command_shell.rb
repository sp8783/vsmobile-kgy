require "open3"

# git・gh コマンドの実行（テストでは差し替える）。env でそのコマンドだけの環境変数を渡せる
class CommandShell
  def capture(*command, env: {})
    output, status = Open3.capture2(env, *command)
    raise "コマンドが失敗しました: #{command.join(' ')}" unless status.success?

    output
  end

  def run(*command, env: {})
    system(env, *command, exception: true)
  end
end
