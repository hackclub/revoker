module TokenTypes
  class SlackXoxb < Base
    self.regex = /\Axoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+\z/
    self.name = "Slack bot token"
    self.hint = "xoxb-..."

    def self.revoke(token, **kwargs)
      Rails.logger.info("SlackXoxb: Starting revocation for bot token")

      client = Slack::Web::Client.new(token:)

      # Step 1: Verify the token and get bot info using auth.test
      Rails.logger.info("SlackXoxb: Calling auth.test")
      test_response = client.auth_test
      Rails.logger.info("SlackXoxb: auth.test response: ok=#{test_response.ok}, bot_id=#{test_response.bot_id}")

      owner_email = nil
      owner_bot_name = test_response.user
      owner_slack_id = nil

      # Step 2: Use bots.info to get app_id, then team.integrationLogs to find installer
      bot_token = ENV["SLACK_BOT_TOKEN"]
      admin_token = ENV["SLACK_ADMIN_TOKEN"]
      if bot_token && admin_token && test_response.bot_id
        Rails.logger.info("SlackXoxb: Looking up app installer")
        bot_client = Slack::Web::Client.new(token: bot_token)
        admin_client = Slack::Web::Client.new(token: admin_token)

        begin
          # Get app_id from bots.info (requires users:read)
          bot_response = bot_client.bots_info(bot: test_response.bot_id)
          Rails.logger.info("SlackXoxb: bots.info response: ok=#{bot_response.ok}")

          if bot_response.ok && bot_response.bot&.app_id
            app_id = bot_response.bot.app_id
            Rails.logger.info("SlackXoxb: Got app_id: #{app_id}")

            # Find who installed the app via integration logs (requires admin)
            logs_response = admin_client.team_integrationLogs(app_id: app_id)
            Rails.logger.info("SlackXoxb: team.integrationLogs response: ok=#{logs_response.ok}")

            if logs_response.ok && logs_response.logs.present?
              # Find the "added" entry (when app was installed)
              install_log = logs_response.logs.find { |log| log.change_type == "added" }
              installer_user_id = install_log&.user_id

              if installer_user_id
                Rails.logger.info("SlackXoxb: Found installer user_id: #{installer_user_id}")
                owner_slack_id = installer_user_id

                # Get installer's email (requires users:read and users:read.email)
                user_response = bot_client.users_info(user: installer_user_id)
                if user_response.ok && user_response.user.profile.email
                  owner_email = user_response.user.profile.email
                  Rails.logger.info("SlackXoxb: Got installer email: #{owner_email}")
                else
                  Rails.logger.warn("SlackXoxb: Could not get installer email, falling back to bot name")
                end
              else
                Rails.logger.warn("SlackXoxb: No install log found, falling back to bot name")
              end
            else
              Rails.logger.warn("SlackXoxb: integrationLogs failed or empty, falling back to bot name")
            end
          else
            Rails.logger.warn("SlackXoxb: bots.info failed or no app_id, falling back to bot name")
          end
        rescue Slack::Web::Api::Errors::SlackError => e
          Rails.logger.warn("SlackXoxb: API error fetching installer info: #{e.message}")
        end
      else
        Rails.logger.warn("SlackXoxb: SLACK_BOT_TOKEN or SLACK_ADMIN_TOKEN not configured, using bot name")
      end

      # Step 3: Revoke the token using auth.revoke
      Rails.logger.info("SlackXoxb: Calling auth.revoke")
      revoke_response = client.auth_revoke
      Rails.logger.info("SlackXoxb: auth.revoke response: ok=#{revoke_response.ok}")

      unless revoke_response.ok
        Rails.logger.warn("SlackXoxb: auth.revoke failed")
        return { success: false }
      end

      Rails.logger.info("SlackXoxb: Token successfully revoked")
      { success: true, owner_email:, owner_slack_id:, key_name: owner_bot_name }
    rescue StandardError => e
      Rails.logger.error("SlackXoxb: Exception during revocation - #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false }
    end

    # Redact: show first segment, hide middle segments, show last 4 of final segment
    def self.redact(token)
      return "" if token.nil? || token.empty?

      parts = token.split("-")
      return token if parts.length < 4

      first = parts[0]
      last_segment = parts[-1]
      last_chars = last_segment.length >= 4 ? last_segment[-4..] : last_segment

      # Use asterisks matching the length of hidden portions
      part1_hidden = "*" * (parts[1].length - 2)
      part2_hidden = "*" * parts[2].length
      part3_hidden = "*" * (parts[3].length - last_chars.length)

      "#{first}-#{parts[1][0..1]}#{part1_hidden}-#{part2_hidden}-#{part3_hidden}#{last_chars}"
    end
  end
end
