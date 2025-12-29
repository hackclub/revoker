class RevocationsController < ApplicationController
  before_action :set_revocation, only: [ :edit, :update ]

  def new
    @revocation = Revocation.new
    @token_types = build_token_types_for_view
  end

  def create
    token = params[:token].to_s.strip
    xoxd = params[:xoxd].to_s.strip.presence # Optional xoxd cookie
    xoxc = params[:xoxc].to_s.strip.presence # Optional xoxc token (for xoxd revocation)

    matched_types = TokenTypes::ALL.select { |t| t.matches?(token) }

    if matched_types.empty?
      flash.now[:error] = "Token doesn't match any supported type."
      @token_types = build_token_types_for_view
      return render :new, status: :unprocessable_entity
    end

    # Special case: if token is xoxd and xoxc is provided, revoke using xoxc with xoxd as cookie
    if matched_types.any? { |t| t == TokenTypes::SlackXoxd } && xoxc.present?
      Rails.logger.info("RevocationsController: xoxd token with xoxc provided, using xoxc revocation flow")
      result = TokenTypes::SlackXoxc.revoke(xoxc, xoxd: token)

      if result[:success]
        # Create revocation record with both tokens noted
        @revocation = Revocation.create(
          token: "#{TokenTypes::SlackXoxd.redact(token)} (with xoxc: #{TokenTypes::SlackXoxc.redact(xoxc)})",
          token_type: "TokenTypes::SlackXoxc",
          owner_email: result[:owner_email],
          owner_slack_id: result[:owner_slack_id],
          key_name: result[:key_name],
          view_id: SecureRandom.uuid,
          status: result[:status] || "complete"
        )
        @revocation.notify_affected_party!
        return redirect_to edit_revocation_path(@revocation)
      else
        flash.now[:error] = "Failed to revoke xoxd+xoxc pair. The tokens may be invalid or already revoked."
        @token_types = build_token_types_for_view
        return render :new, status: :unprocessable_entity
      end
    end

    # Try revoking with each matched type until one succeeds
    result = nil
    successful_type = nil

    matched_types.each do |token_type|
      result = token_type.revoke(token, xoxd: xoxd, xoxc: xoxc)
      if result[:success]
        successful_type = token_type
        break
      end
    end

    if successful_type.nil?
      flash.now[:error] = "This token seems to be invalid or already revoked."
      @token_types = build_token_types_for_view
      return render :new, status: :unprocessable_entity
    end

    # Create revocation record
    @revocation = Revocation.create(
      token: successful_type.redact(token),
      token_type: successful_type.to_s,
      owner_email: result[:owner_email],
      owner_slack_id: result[:owner_slack_id],
      key_name: result[:key_name],
      view_id: SecureRandom.uuid,
      status: result[:status] || "complete"
    )

    @revocation.lookup_slack_id_by_email if @revocation.owner_slack_id.blank?
    @revocation.notify_affected_party!

    redirect_to edit_revocation_path(@revocation)
  end

  def show
    @revocation = Revocation.find_by!(view_id: params[:id])
  end

  def edit
  end

  def update
    @revocation.update!(
      submitter: params[:submitter],
      comment: params[:comment]
    )
    redirect_to root_path, notice: "Thank you! Got another?"
  end

  private

  def set_revocation
    @revocation = Revocation.find(params[:id])
  end

  def build_token_types_for_view
    TokenTypes::ALL.map do |token_type|
      regex_source = token_type.regex.source
        .gsub('\\A', "^")
        .gsub('\\z', "$")

      {
        name: token_type.display_name,
        regex: regex_source,
        hint: token_type.hint
      }
    end
  end
end
