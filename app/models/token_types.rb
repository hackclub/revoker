module TokenTypes
  # Registry of all token types
  ALL = [
    AirtablePAT,
    FlavortownAPIKey,
    HackClubAiAPIKey,
    HackClubSearchAPIKey,
    HackatimeAdminKey,
    HackClubCDNAPIKey,
    HCBOAuth,
    SlackXoxb,
    SlackXoxp,
    SlackXoxc,
    SlackXoxd,
    TheseusAPIKey,
    TheseusPublicAPIKey,
    HackatimeToken
  ].freeze

  def self.find(value)
    ALL.select { |token_type| token_type.matches?(value) }
  end

  def self.detect_type(value)
    token_types = find(value)
    return "Unknown" if token_types.empty?

    token_types.map(&:display_name).join(", ")
  end
end

require_relative "token_types/base"
require_relative "token_types/airtable_pat"
require_relative "token_types/flavortown_api_key"
require_relative "token_types/hack_club_ai_api_key"
require_relative "token_types/hack_club_search_api_key"
require_relative "token_types/hackatime_admin_key"
require_relative "token_types/hack_club_cdn_api_key"
require_relative "token_types/hcb_oauth"
require_relative "token_types/slack_xoxb"
require_relative "token_types/slack_xoxp"
require_relative "token_types/slack_xoxc"
require_relative "token_types/slack_xoxd"
require_relative "token_types/theseus_api_key"
require_relative "token_types/hackatime_token"