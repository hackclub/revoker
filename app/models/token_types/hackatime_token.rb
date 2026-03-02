module TokenTypes
  class HackatimeToken < Base
    self.regex = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    self.name = "Hackatime v2 API key"

    def self.revoke(token, **_kwargs)
      logger_prefix = "HackatimeToken"
      Rails.logger.info("#{logger_prefix}: Starting revocation for token")

      hackatime_url = ENV["HACKATIME_API_URL"] || "http://localhost:3000"
      auth_token = ENV["HACKATIME_AUTH_TOKEN"]

      unless auth_token
        Rails.logger.error("#{logger_prefix}: HACKATIME_AUTH_TOKEN not configured")
        Sentry.capture_message("HACKATIME_AUTH_TOKEN not configured", level: :error)
        return { success: false }
      end

      begin
        connection = Faraday.new(url: hackatime_url) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        Rails.logger.info("#{logger_prefix}: Making POST request to #{hackatime_url}/api/internal/revoke")

        response = connection.post("/api/internal/revoke", {}, {
          "Authorization" => "Bearer #{auth_token}"
        }) do |req|
          req.params["token"] = token
        end

        body = response.body
        Rails.logger.info("#{logger_prefix}: Response status=#{response.status}, body=#{body.inspect}")

        if response.success? && body["success"]
          owner_email = body["owner_email"]
          key_name = body["key_name"]
          status = body["status"]
          Rails.logger.info("#{logger_prefix}: Token revoked, owner_email=#{owner_email}, key_name=#{key_name}, status=#{status}")
          result = { success: true, owner_email: owner_email }
          result[:key_name] = key_name if key_name
          result[:status] = status.to_sym if status
          result
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
