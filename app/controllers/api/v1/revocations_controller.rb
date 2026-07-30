module API
  module V1
    class RevocationsController < ApplicationController
      def create
        token = params[:token].to_s.strip

        if token.blank?
          return render json: {
            success: false,
            error: "Token is required",
            params: params.to_unsafe_h,
            content_type: request.content_type,
            content_mime_type: request.content_mime_type.to_s,
            mime_ref: request.content_mime_type&.ref.inspect,
            raw_post: request.raw_post,
            request_params: request.request_parameters
          }, status: :unprocessable_entity
        end

        matched_types = TokenTypes::ALL.select { |t| t.matches?(token) }

        if matched_types.empty?
          return render json: { success: false, error: "Token doesn't match any supported type" }, status: :unprocessable_entity
        end

        result = nil
        successful_type = nil

        matched_types.each do |token_type|
          result = token_type.revoke(token)
          if result[:success]
            successful_type = token_type
            break
          end
        end

        if successful_type.nil?
          return render json: { success: false, error: "Token is invalid or already revoked" }, status: :unprocessable_entity
        end

        status = result[:status] || "complete"

        token_type = successful_type.to_s

        revocation = Revocation.create(
          token: successful_type.redact(token),
          token_type:,
          owner_email: result[:owner_email],
          owner_slack_id: result[:owner_slack_id],
          key_name: result[:key_name],
          extra_info: result[:extra_info],
          view_id: SecureRandom.uuid,
          status:,
          submitter: params[:submitter],
          comment: params[:comment],
          from_api: true
        )

        revocation.lookup_slack_id_by_email if revocation.owner_slack_id.blank?
        revocation.notify_affected_party!

        res = {
          success: true,
          status:,
          token_type: successful_type.display_name,
          owner_email: revocation.owner_email.presence,
          key_name: revocation.key_name.presence
        }.compact

        res[:action_needed] = "Manual intervention required to complete revocation" if status == "action_needed"

        render json: res, status: :created
      end
    end
  end
end
