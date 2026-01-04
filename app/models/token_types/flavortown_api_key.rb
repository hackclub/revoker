module TokenTypes
  class FlavortownAPIKey < Base
    self.regex = /\Aft_sk_[0-9a-f]{40}\z/
    self.name = "Flavortown API key"
    self.hint = "ft_sk_..."
    self.service_owner_emails = %w[]

    def self.revoke(token, **kwargs)
      connection = Faraday.new(url: "https://flavortown.hackclub.com") do |faraday|
        faraday.request :json
        faraday.response :json
      end

      response = connection.post("/internal/revoke", { token: })

      return { success: false } unless response.success?

      body = response.body

      { success: true, owner_email: body["owner_email"], key_name: body["key_name"] }
    rescue
      { success: false }
    end

    def self.redact(token)
      prefix = "ft_sk_"
      hex_part = token[prefix.length..]
      "#{prefix}#{hex_part[0..2]}#{"*" * [ hex_part.length - 6, 3 ].max}#{hex_part[-3..]}"
    end
  end
end
