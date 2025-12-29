class Revocation < AirpplicationRecord
  self.table_name = "Revocations"

  field :token, "token"
  field :token_type, "token_type"
  field :owner_email, "owner_email"
  field :owner_slack_id, "owner_slack_id"
  field :submitter, "submitter"
  field :comment, "comment"
  field :view_id, "view_id"
  field :status, "status"

  def notify_affected_party!
    AffectedPartyNotifier.new(self).notify!
  end

  def token_type_class = TokenTypes::ALL.find { |tt| tt.name == token_type }

  def lookup_slack_id_by_email
    return if owner_email.blank?
    return if owner_slack_id.present?

    bot_token = ENV["SLACK_BOT_TOKEN"]
    return unless bot_token

    begin
      Rails.logger.info("Revocation: Looking up Slack user ID for email: #{owner_email}")
      client = Slack::Web::Client.new(token: bot_token)

      # Use users.lookupByEmail to find the user
      response = client.users_lookupByEmail(email: owner_email)

      if response.ok && response.user&.id
        self.owner_slack_id = response.user.id
        save
        Rails.logger.info("Revocation: Found Slack user ID: #{owner_slack_id}")
        owner_slack_id
      else
        Rails.logger.warn("Revocation: Could not find Slack user for email: #{owner_email}")
        nil
      end
    rescue Slack::Web::Api::Errors::UsersNotFound => e
      Rails.logger.warn("Revocation: User not found in Slack for email: #{owner_email}")
      nil
    rescue StandardError => e
      Rails.logger.error("Revocation: Error looking up Slack user - #{e.class}: #{e.message}")
      Sentry.capture_exception(e)
      nil
    end
  end
end
