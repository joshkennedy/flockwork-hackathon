require "net/http"

module Planner
  class VoiceClientSecretMinter
    ENDPOINT = URI("https://api.x.ai/v1/realtime/client_secrets")
    EXPIRATION_SECONDS = 300

    class Error < StandardError; end

    def call
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{ENV.fetch("XAI_API_KEY")}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(expires_after: { seconds: EXPIRATION_SECONDS })

      response = Net::HTTP.start(
        ENDPOINT.host,
        ENDPOINT.port,
        use_ssl: true,
        open_timeout: 5,
        read_timeout: 10
      ) { |http| http.request(request) }
      raise Error, "xAI client secret request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("value").presence || raise(Error, "xAI returned an empty client secret")
    rescue Error
      raise
    rescue StandardError => error
      raise Error, "xAI client secret request failed: #{error.class}"
    end
  end
end
