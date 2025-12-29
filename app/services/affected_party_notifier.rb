class AffectedPartyNotifier
  def initialize(revocation)
    @revocation = revocation
  end

  def notify!
    return unless should_notify?

    notify_via_slack if @revocation.owner_slack_id.present?
    notify_via_email if @revocation.owner_email.present?
  end

  private

  def should_notify? = true

  def notify_via_slack
    client = Slack::Web::Client.new(token: ENV["SLACK_BOT_TOKEN"])

    payload = ApplicationController.renderer.render(
      template: slack_template,
      formats: [ :slack_message ],
      assigns: { revocation: @revocation, revocation_url: revocation_url }
    )

    users = [ @revocation.owner_slack_id, ENV["NORA_SLACK_ID"] ].compact.uniq
    conversation = client.conversations_open(users: users.join(","))

    client.chat_postMessage(
      channel: conversation.channel.id,
      **JSON.parse(payload, symbolize_names: true)
    )
  rescue StandardError => e
    Rails.logger.error("AffectedPartyNotifier: Slack notification failed - #{e.class}: #{e.message}")
    Sentry.capture_exception(e)
  end

  def notify_via_email
    transactional_id = loops_transactional_id
    return unless transactional_id

    conn = Faraday.new(url: "https://app.loops.so") do |f|
      f.request :json
      f.response :json
      f.adapter :net_http_persistent
    end

    conn.post("/api/v1/transactional") do |req|
      req.headers["Authorization"] = "Bearer #{ENV['LOOPS_API_KEY']}"
      req.body = {
        transactionalId: transactional_id,
        email: @revocation.owner_email,
        dataVariables: email_data_variables.merge(cc_data_variables)
      }
    end
  rescue StandardError => e
    Rails.logger.error("AffectedPartyNotifier: Email notification failed - #{e.class}: #{e.message}")
    Sentry.capture_exception(e)
  end

  def slack_template
    case @revocation.status
    when "action_needed"
      "notifications/action_needed"
    else
      "notifications/revoked"
    end
  end

  def loops_transactional_id
    case @revocation.status
    when "action_needed"
      ENV["LOOPS_ACTION_NEEDED_TRANSACTIONAL_ID"]
    else
      ENV["LOOPS_REVOKED_TRANSACTIONAL_ID"]
    end
  end

  def email_data_variables
    {
      tokenType: token_display_name,
      status: @revocation.status,
      comment: @revocation.comment || "",
      submitter: @revocation.submitter || "",
      token: @revocation.token,
      revocationUrl: revocation_url
    }
  end

  def token_display_name
    token_type_class&.display_name || @revocation.token_type
  end

  def revocation_url
    host = ENV.fetch("APP_HOST", "http://localhost:3000")
    "#{host}/revocations/#{@revocation.view_id}"
  end

  def cc_data_variables
    emails = token_type_class&.service_owner_emails || []
    return {} if emails.empty?

    { ccAddress: emails.join(",") }
  end

  def token_type_class
    @revocation.token_type.constantize
  rescue
    nil
  end
end
