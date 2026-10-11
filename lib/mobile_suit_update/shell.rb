require "open3"

module MobileSuitUpdate
  # git・gh コマンドの実行（テストでは差し替える）
  class Shell
    def capture(*command)
      output, status = Open3.capture2(*command)
      raise "コマンドが失敗しました: #{command.join(' ')}" unless status.success?

      output
    end

    def run(*command)
      system(*command, exception: true)
    end
  end
end
