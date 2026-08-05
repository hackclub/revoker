module TokenTypes
  class GitHubToken < Base
    self.regex = /\A(gh[ouprs]_|github_pat_)[A-Za-z0-9_]+\z/
    self.name = "GitHub Token"
    self.hint = "ghp_..., github_pat_..., ghs_..."

    GITHUB_API = "https://api.github.com"

    def self.revoke(token, **_kwargs)
      logger_prefix = "GitHubToken"
      Rails.logger.info("#{logger_prefix}: Starting revocation")

      begin
        connection = Faraday.new(url: GITHUB_API) do |faraday|
          faraday.request :json
          faraday.response :json
        end

        owner_info = identify_owner(connection, token)
        Rails.logger.info("#{logger_prefix}: Owner: #{owner_info.inspect}")

        if token.start_with?("ghs_")
          revoke_installation_token(connection, token, owner_info)
        else
          revoke_via_credentials(connection, token, owner_info)
        end
      rescue StandardError => e
        Rails.logger.error("#{logger_prefix}: #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        sentry_id = Sentry.capture_exception(e)
        { success: false, error: "Internal error during revocation", sentry_id: }
      end
    end

    def self.redact(token)
      return "" if token.nil? || token.empty?

      prefix = if token.start_with?("github_pat_")
        "github_pat_"
      else
        token[/\Agh[ouprs]_/]
      end

      return super unless prefix

      rest = token[prefix.length..]
      return token if rest.length <= 6

      "#{prefix}#{rest[0..2]}#{"*" * [rest.length - 6, 3].max}#{rest[-3..]}"
    end

    class << self
      private

      def identify_owner(connection, token)
        if token.start_with?("ghs_")
          identify_installation(connection, token)
        else
          identify_user(connection, token)
        end
      end

      def identify_user(connection, token)
        response = connection.get("/user") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
        end

        if response.success?
          body = response.body
          scopes = response.headers["x-oauth-scopes"]
          login = body["login"]

          extra_parts = []
          extra_parts << "user: #{login}" if login
          extra_parts << "scopes: #{scopes.presence || "(none)"}" if scopes

          {
            owner_email: body["email"],
            key_name: login,
            extra_info: extra_parts.join("\n").presence
          }
        else
          Rails.logger.warn("GitHubToken: /user returned #{response.status}, proceeding without owner info")
          {}
        end
      end

      def identify_installation(connection, token)
        extra_parts = []

        app_id = token.match(/\Aghs_(\d+)_/)&.captures&.first
        extra_parts << "app id: #{app_id}" if app_id

        response = connection.get("/installation/repositories") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
          req.params["per_page"] = 1
        end

        if response.success? && response.body["repositories"]&.any?
          repo = response.body["repositories"].first
          owner = repo.dig("owner", "login")
          total = response.body["total_count"]

          extra_parts << "installation for: #{owner}" if owner
          extra_parts << "repos: #{total}" if total

          { key_name: owner, extra_info: extra_parts.join("\n").presence }
        else
          Rails.logger.warn("GitHubToken: /installation/repositories returned #{response.status}, proceeding without info")
          { extra_info: extra_parts.join("\n").presence }
        end
      end

      def revoke_installation_token(connection, token, owner_info)
        response = connection.delete("/installation/token") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
        end

        if response.status == 204
          Rails.logger.info("GitHubToken: Installation token revoked")
          { success: true, **owner_info }
        else
          Rails.logger.warn("GitHubToken: DELETE /installation/token returned #{response.status}")
          { success: false }
        end
      end

      def revoke_via_credentials(connection, token, owner_info)
        response = connection.post("/credentials/revoke", { credentials: [token] }) do |req|
          req.headers["Accept"] = "application/vnd.github+json"
        end

        if response.status == 202
          Rails.logger.info("GitHubToken: Token accepted for revocation")
          { success: true, **owner_info }
        else
          Rails.logger.warn("GitHubToken: POST /credentials/revoke returned #{response.status}")
          { success: false }
        end
      end
    end
  end
end
