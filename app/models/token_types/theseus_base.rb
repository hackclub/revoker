module TokenTypes
  class TheseusBase < Base
    def self.revoke(token, **kwargs)
      logger_prefix = self.name || self.class.name.demodulize
      Rails.logger.info("#{logger_prefix}: Starting revocation for token")

      theseus_url = ENV["THESEUS_API_URL"] || "http://localhost:3000"
      auth_header = ENV["THESEUS_AUTH_TOKEN"]

      unless auth_header
        Rails.logger.error("#{logger_prefix}: THESEUS_AUTH_TOKEN not configured")
        Sentry.capture_message("THESEUS_AUTH_TOKEN not configured", level: :error)
        return { success: false }
      end

      begin
        connection = Faraday.new(url: theseus_url) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        Rails.logger.info("#{logger_prefix}: Making POST request to #{theseus_url}/api/revoke")

        response = connection.post("/api/revoke", {}, {
          "Authorization" => auth_header
        }) do |req|
          req.params["token"] = token
        end

        body = response.body
        Rails.logger.info("#{logger_prefix}: Response status=#{response.status}, body=#{body.inspect}")

        if response.success? && body["success"]
          owner_email = body["owner_email"] || "unknown@example.com"
          key_name = body["key_name"]
          Rails.logger.info("#{logger_prefix}: Token successfully revoked, owner_email=#{owner_email}, key_name=#{key_name}")
          { success: true, owner_email: owner_email, key_name: key_name }
        else
          Rails.logger.warn("#{logger_prefix}: API request failed or returned success=false")
          { success: false }
        end
      rescue StandardError => e
        Rails.logger.error("#{logger_prefix}: Exception during revocation - #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        Sentry.capture_exception(e)
        { success: false }
      end
    end
  end
end
