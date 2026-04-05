require "net/http"

class GithubActionsWorkflowDispatcher
  Result = Struct.new(:success?, :error_message, keyword_init: true)

  def initialize(repo:, workflow_id:, token:, inputs:, missing_config_message:, exception_message_prefix:, ref: "main")
    @repo = repo
    @workflow_id = workflow_id
    @token = token
    @inputs = inputs
    @missing_config_message = missing_config_message
    @exception_message_prefix = exception_message_prefix
    @ref = ref
  end

  def call
    return Result.new(success?: false, error_message: missing_config_message) if missing_config?

    response = http.request(request)
    if response.is_a?(Net::HTTPNoContent)
      Result.new(success?: true)
    else
      Result.new(success?: false, error_message: "GitHub Actions のトリガーに失敗しました（HTTP #{response.code}）。")
    end
  rescue => error
    Result.new(success?: false, error_message: "#{exception_message_prefix}: #{error.message}")
  end

  private

  attr_reader :repo, :workflow_id, :token, :inputs, :missing_config_message, :exception_message_prefix, :ref

  def missing_config?
    repo.blank? || workflow_id.blank? || token.blank?
  end

  def http
    uri = dispatch_uri
    Net::HTTP.new(uri.host, uri.port).tap do |client|
      client.use_ssl = true
    end
  end

  def request
    Net::HTTP::Post.new(dispatch_uri.path, {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/vnd.github+json",
      "Content-Type" => "application/json",
      "X-GitHub-Api-Version" => "2022-11-28"
    }).tap do |http_request|
      http_request.body = { ref: ref, inputs: inputs }.to_json
    end
  end

  def dispatch_uri
    @dispatch_uri ||= URI("https://api.github.com/repos/#{repo}/actions/workflows/#{workflow_id}/dispatches")
  end
end
