module TokenTypes
  class CdnAPIKey < Base
    self.regex = /\Ask_cdn_[a-f0-9]{64}\z/
    self.name = "Hack Club CDN API key"
    self.hint = "sk_cdn_..."
    self.service_owner_emails = %w[nora@hackclub.com]

    def self.revoke(token, **kwargs)
      connection = Faraday.new(url: "https://cdn.hackclub.com") do |faraday|
        faraday.request :json
        faraday.response :json
      end

      response = connection.post("/api/v4/revoke", {}, {
        "Authorization" => "Bearer #{token}"
      })

      return { success: false } unless response.success?

      body = response.body

      { success: true, owner_email: body["owner_email"], key_name: body["key_name"] }
    rescue
      { success: false }
    end

    def self.redact(token)
      prefix = "sk_cdn_"
      hex_part = token[prefix.length..]
      "#{prefix}#{hex_part[0..2]}#{"*" * [ hex_part.length - 6, 3 ].max}#{hex_part[-3..]}"
    end
  end
end
