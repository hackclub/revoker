module TokenTypes
  class AttendAPIKey < Base
    # attend.hackclub.com tokens: "attn_" + urlsafe_base64 (named tokens) or
    # + hex (legacy per-event keys). Both are covered by [A-Za-z0-9_-].
    self.regex = /\Aattn_[A-Za-z0-9_-]{20,}\z/
    self.name = "attend.hackclub.com API key"
    self.hint = "attn_..."

    def self.revoke(token, **_kwargs)
      base_url = ENV["ATTEND_API_URL"] || "https://attend.hackclub.com"

      connection = Faraday.new(url: base_url) do |faraday|
        faraday.request :json
        faraday.response :json
      end

      # No credentials needed: the token being revoked is itself the proof of
      # authorization on Attend's side.
      response = connection.post("/api/v1/tokens/revoke", { token: })

      return { success: false } unless response.success?

      body = response.body
      return { success: false } unless body.is_a?(Hash) && body["success"]

      { success: true, owner_email: body["owner_email"], key_name: body["key_name"] }
    rescue StandardError => e
      Rails.logger.error("AttendAPIKey: #{e.class}: #{e.message}")
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
