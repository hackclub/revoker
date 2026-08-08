module TokenTypes
  class SlackXoxd < Base
    self.regex = /\Axoxd-[a-zA-Z0-9+\/%=]+\z/
    self.name = "scraped Slack client cookie"
    self.hint = "xoxd-..."

    def self.revoke(token, **kwargs)
      xoxc = kwargs[:xoxc]

      Rails.logger.info("SlackXoxd: Starting revocation for xoxd cookie")

      # xoxd cookies cannot be revoked without their corresponding xoxc token
      unless xoxc.present?
        Rails.logger.warn("SlackXoxd: xoxd tokens cannot be revoked standalone - xoxc token is required")

        # Try to get user email even though we can't revoke yet
        owner_email = nil
        owner_slack_id = nil
        begin
          workspace_domain = ENV["SLACK_WORKSPACE_DOMAIN"] || "hackclub.enterprise.slack.com"
          boot_url = "https://#{workspace_domain}/api/client.userBoot"

          Rails.logger.info("SlackXoxd: Attempting to get user email via client.userBoot")

          connection = Faraday.new do |f|
            f.request :multipart
            f.request :url_encoded
            f.adapter Faraday.default_adapter
          end

          headers = {
            "User-Agent" => "revoker/1.0",
            "Accept" => "*/*",
            "Cookie" => "d=#{CGI.escape(token)}"
          }

          boot_response = connection.post(boot_url) do |req|
            req.headers = headers
            req.body = { _x_sonic: "true" }
          end

          if boot_response.status == 200
            boot_json = JSON.parse(boot_response.body)
            if boot_json["ok"] && boot_json.dig("self", "profile", "phone")
              owner_email = boot_json.dig("self", "profile", "phone")
              owner_slack_id = boot_json.dig("self", "id")
              Rails.logger.info("SlackXoxd: Got user email: #{owner_email}, user_id: #{owner_slack_id}")
            end
          end
        rescue => e
          Rails.logger.warn("SlackXoxd: Failed to get email: #{e.message}")
        end

        # If we got the email, return success with action_needed status
        if owner_email.present?
          Rails.logger.info("SlackXoxd: Returning action_needed status with email")
          return {
            success: true,
            status: :action_needed,
            owner_email:,
            owner_slack_id:
          }
        end

        # If we couldn't get the email, return the original error
        return {
          success: false,
          error: "xoxd cookies require the matching xoxc token for revocation. Please provide both tokens together."
        }
      end

      # Delegate to SlackXoxc since it needs both tokens together
      Rails.logger.info("SlackXoxd: Delegating to SlackXoxc with xoxd cookie")
      TokenTypes::SlackXoxc.revoke(xoxc, xoxd: token)
    end

    # Redact: show prefix, hide most of the content, show last 4 chars
    def self.redact(token)
      return "" if token.nil? || token.empty?
      return token if token.length <= 10

      first = token[0..6]  # "xoxd-"
      last = token[-4..]
      asterisks = "*" * [ token.length - 11, 10 ].max

      "#{first}#{asterisks}#{last}"
    end
  end
end
