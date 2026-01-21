# the revoker

<https://revoke.hackclub.com>

revoke leaked tokens: paste one in, it gets detected and revoked automatically. the token owner gets notified via slack DM and email.

## supported tokens

- airtable PATs
- flavortown API keys
- hack club AI API keys
- hack club search API keys
- hackatime admin keys
- HCB OAuth tokens
- slack tokens (xoxb, xoxp, xoxc, xoxd)
- theseus API keys

## setup

```bash
bundle install
yarn install
bin/dev
```

create `.env.development`:

```env
AIRTABLE_BASE_KEY=appXXX
AIRTABLE_PAT=patXXX
```

## adding a new token type

run a Hack Club service with API keys? please add support! when tokens leak (and they will), fast revocation protects your users. it only takes a few lines of code and a PR.

create a class in `app/models/token_types/`:

```ruby
module TokenTypes
  class CoolServiceToken < Base
    self.regex = /\Ayour-prefix-[a-zA-Z0-9]+\z/
    self.name = "CoolService 3000 API key"

    # call your API to revoke the token
    # return { success: false } if the token isn't valid
    # return { success: true, owner_email: "..." } on success
    # optional: add key_name: "..." to identify the specific key in notifications
    # optional: add status: "action_needed" if manual intervention is required
    def self.revoke(token, **kwargs)
      resp = Faraday.post("https://coolservice.hackclub.com/revoke", { token: }.to_json, "Content-Type" => "application/json")
      return { success: false } unless resp.success?

      data = JSON.parse(resp.body)
      { success: true, owner_email: data["owner_email"] }
    end
  end
end
```

then add it to the registry in `app/models/token_types.rb`:

```ruby
ALL = [
  AirtablePAT,
  CoolServiceToken,  # add yours here
  # ...
].freeze
```
