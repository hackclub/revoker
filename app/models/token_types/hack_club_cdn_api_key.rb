module TokenTypes
  class HackClubCDNAPIKey < Base
    self.regex = /\Ask_cdn_[a-f0-9]{64}\z/
    self.name = "Hack Club CDN API key"
    self.hint = "sk_cdn_..."
    self.service_owner_emails = %w[nora@hackclub.com]

    def self.revoke(token, **kwargs)
      Rails.logger.info("HackClubCDNAPIKey: Starting revocation for token")

      cdn_api_url = ENV.fetch("HC_CDN_API_URL", "https://cdn.hackclub.com")

      begin
        connection = Faraday.new(url: cdn_api_url) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        Rails.logger.info("HackClubCDNAPIKey: Making POST request to #{cdn_api_url}/api/v4/revoke")

        response = connection.post("/api/v4/revoke", {}, {
          "Authorization" => "Bearer #{token}"
        })

        body = response.body
        Rails.logger.info("HackClubCDNAPIKey: Response status=#{response.status}, body=#{body.inspect}")

        if response.success? && body["success"]
          owner_email = body["owner_email"]
          key_name = body["key_name"]
          Rails.logger.info("HackClubCDNAPIKey: Token successfully revoked, owner_email=#{owner_email}, key_name=#{key_name}")
          { success: true, owner_email:, key_name: }
        else
          Rails.logger.warn("HackClubCDNAPIKey: API request failed or returned success=false")
          { success: false }
        end
      rescue StandardError => e
        Rails.logger.error("HackClubCDNAPIKey: Exception during revocation - #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        sentry_id = Sentry.capture_exception(e)
        { success: false, error: "Internal error during revocation", sentry_id: }
      end
    end
  end
end
