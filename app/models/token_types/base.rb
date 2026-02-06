module TokenTypes
  class Base
    class_attribute :regex, default: nil
    class_attribute :name, default: nil
    class_attribute :hint, default: nil
    class_attribute :service_owner_emails, default: []

    def self.matches?(value) = regex.present? && value.match?(regex)

    def self.display_name = name || self.class.name.demodulize

    # Attempt to revoke the token. Returns a hash:
    #   { success: true, owner_email: "...", status: "complete" } on immediate success
    #   { success: true, owner_email: "...", status: "action_needed" } when manual intervention required
    #   { success: false } when token is invalid or already revoked
    #   { success: false, error: "...", sentry_id: "..." } on internal error (exception caught)
    #
    # Optional return fields:
    #   - key_name: identifier for the specific key (e.g., bot name, key label like "msw@hackatime")
    #   - owner_slack_id: Slack user ID of the token owner
    #   - error: human-readable error message when an exception occurred
    #   - sentry_id: Sentry event ID for tracking internal errors
    #
    # Optional parameters for tokens that require companion tokens (e.g., Slack xoxc/xoxd pairs)
    # Status defaults to "complete" if not specified
    def self.revoke(token, **kwargs)
      raise NotImplementedError, "#{self.name} must implement .revoke(token, **kwargs)"
    end

    # Redact a token for display (show first 7 chars, asterisks, last 3)
    def self.redact(token)
      return "" if token.nil? || token.empty?
      return token if token.length <= 10

      first = token[0..6]
      last = token[-3..]
      asterisks = "*" * [ token.length - 10, 3 ].max

      "#{first}#{asterisks}#{last}"
    end
  end
end
