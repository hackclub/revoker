module TokenTypes
  class HackClubAiApiKey < Base
    self.regex = /\Ask-hc-v1-[0-9a-f]{64}\z/
    self.name = "Hack Club AI Key"
    self.hint = "sk-hc-v1-..."
    self.service_owner_emails = %w[mahad@hackclub.com]

    def self.revoke(token, **kwargs)
      connection = Faraday.new(url: "https://ai.hackclub.com") do |faraday|
        faraday.request :json
        faraday.response :json
      end

      response = connection.post("/internal/revoke", { token: }, {
        "Authorization" => "Bearer #{ENV["HCAI_REVOKER_KEY"]}"
      })

      return { success: false } unless response.success?

      body = response.body

      { success: true, owner_email: body["owner_email"], key_name: body["key_name"] }
    rescue
      { success: false }
    end

    def self.redact(token)
      prefix = "sk-hc-v1-"
      hex_part = token[prefix.length..]
      "#{prefix}#{hex_part[0..2]}#{"*" * [ hex_part.length - 6, 3 ].max}#{hex_part[-3..]}"
    end
  end
end
