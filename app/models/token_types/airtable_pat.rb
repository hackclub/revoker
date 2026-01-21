module TokenTypes
  class AirtablePAT < Base
    self.regex = /\Apat[a-zA-Z0-9]{5,}\.[0-9a-fA-F]{10,}\z/
    self.name = "Airtable Personal Access Token"
    self.hint = "pat..."

    def self.revoke(token, **kwargs)
      logger_prefix = "AirtablePAT"
      Rails.logger.info("#{logger_prefix}: Starting revocation for token")

      tablecloth_host = ENV["TABLECLOTH_HOST"]
      tablecloth_token = ENV["TABLECLOTH_TOKEN"]

      unless tablecloth_host
        Rails.logger.error("#{logger_prefix}: TABLECLOTH_HOST not configured")
        Sentry.capture_message("TABLECLOTH_HOST not configured", level: :error)
        return { success: false }
      end

      unless tablecloth_token
        Rails.logger.error("#{logger_prefix}: TABLECLOTH_TOKEN not configured")
        Sentry.capture_message("TABLECLOTH_TOKEN not configured", level: :error)
        return { success: false }
      end

      begin
        connection = Faraday.new(url: tablecloth_host) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        Rails.logger.info("#{logger_prefix}: Making POST request to #{tablecloth_host}/revoke")

        response = connection.post("/revoke", { token: }, {
          "Authorization" => "Bearer #{tablecloth_token}"
        })

        body = response.body
        Rails.logger.info("#{logger_prefix}: Response status=#{response.status}, body=#{body.inspect}")

        if response.success? && body["success"]
          owner_email = body["owner_email"]
          status = body["status"]
          Rails.logger.info("#{logger_prefix}: Token revoked, owner_email=#{owner_email}, status=#{status}")
          result = { success: true, owner_email: }
          result[:status] = status.to_sym if status
          result
        else
          error_msg = body["error"] if body.is_a?(Hash)
          Rails.logger.warn("#{logger_prefix}: API request failed - #{error_msg}")
          { success: false }
        end
      rescue StandardError => e
        Rails.logger.error("#{logger_prefix}: Exception during revocation - #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        Sentry.capture_exception(e)
        { success: false }
      end
    end

    # Redact: show prefix + dot, then first 3 and last 3 of hash
    def self.redact(token)
      return "" if token.nil? || token.empty?

      parts = token.split(".", 2)
      return token if parts.length != 2

      prefix = parts[0]
      hash = parts[1]

      return token if hash.length <= 6

      "#{prefix}.#{hash[0..2]}#{"*" * (hash.length - 6)}#{hash[-3..]}"
    end
  end
end
