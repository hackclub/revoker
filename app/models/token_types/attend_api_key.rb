module TokenTypes
  class AttendApiKey < Base
    # attend.hackclub.com tokens: "attn_" + urlsafe_base64 (named tokens) or
    # + hex (legacy per-event keys). Both are covered by [A-Za-z0-9_-].
    self.regex = /\Aattn_[A-Za-z0-9_-]{20,}\z/
    self.name = "attend.hackclub.com API key"
    self.hint = "attn_..."

    def self.revoke(token, **_kwargs)
      base_url = ENV["ATTEND_API_URL"] || "https://attend.hackclub.com"
      auth_token = ENV["ATTEND_AUTH_TOKEN"]

      unless auth_token
        Rails.logger.error("AttendApiKey: ATTEND_AUTH_TOKEN not configured")
        Sentry.capture_message("ATTEND_AUTH_TOKEN not configured", level: :error)
        return { success: false }
      end

      connection = Faraday.new(url: base_url) do |faraday|
        faraday.request :json
        faraday.response :json
      end

      response = connection.post("/api/v1/tokens/revoke", { token: }, {
        "Authorization" => "Bearer #{auth_token}"
      })

      return { success: false } unless response.success?

      body = response.body
      return { success: false } unless body.is_a?(Hash) && body["success"]

      { success: true, owner_email: body["owner_email"], key_name: body["key_name"] }
    rescue StandardError => e
      Rails.logger.error("AttendApiKey: #{e.class}: #{e.message}")
      Sentry.capture_exception(e)
      { success: false }
    end

    def self.redact(token)
      return "" if token.nil? || token.empty?
      return token if token.length <= 10

      prefix = "attn_"
      data = token[prefix.length..]
      "#{prefix}#{data[0..2]}#{'*' * [ data.length - 6, 3 ].max}#{data[-3..]}"
    end
  end
end
