module TokenTypes
  class HCBOAuth < Base
    self.regex = /\Ahcb_[a-zA-Z0-9_-]{30,}\z/
    self.name = "HCB V4 API token"
    self.hint = "hcb_..."

    def self.revoke(token, **kwargs)
      Rails.logger.info("HCBOAuth: Starting revocation for token")

      hcb_api_url = ENV.fetch("HCB_API_URL", "https://hcb.hackclub.com")

      begin
        connection = Faraday.new(url: hcb_api_url) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        Rails.logger.info("HCBOAuth: Making POST request to #{hcb_api_url}/api/v4/user/revoke")

        response = connection.post("/api/v4/user/revoke", {}, {
          "Authorization" => "Bearer #{token}"
        })

        body = response.body
        Rails.logger.info("HCBOAuth: Response status=#{response.status}, body=#{body.inspect}")

        if response.success? && body["success"]
          owner_email = body["owner_email"]
          key_name = body["key_name"]
          Rails.logger.info("HCBOAuth: Token successfully revoked, owner_email=#{owner_email}, key_name=#{key_name}")
          { success: true, owner_email:, key_name: }
        else
          Rails.logger.warn("HCBOAuth: API request failed or returned success=false")
          { success: false }
        end
      rescue StandardError => e
        Rails.logger.error("HCBOAuth: Exception during revocation - #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        sentry_id = Sentry.capture_exception(e)
        { success: false, error: "Internal error during revocation", sentry_id: }
      end
    end
  end
end
