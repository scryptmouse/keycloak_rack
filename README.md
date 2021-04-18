# keycloak_rack

An opinionated, convention-over-configuration gem to authenticate Rack (and Rails) applications
against a [Keycloak](https://www.keycloak.org/) installation. It uses a lot of features from the
[dry-rb ecosystem](https://dry-rb.org), and works well in applications that do the same.

In particular, it adopts a [monadic approach](https://dry-rb.org/gems/dry-monads/1.3/) to authentication flow control,
allowing for more granularity in how the whole process is handled.

## Install

```ruby
gem "keycloak_rack", "1.0.0"
```

### Ruby & Rails Versions

- Ruby 2.7, 3.0
- Rails 6.0, 6.1, or using only Rack 2.2

It has also been tested on Rails 5.2, but isn't officially supported because it doesn't support Ruby 3.

At minimum, it requires Ruby 2.7, because it makes use of [pattern matching](https://docs.ruby-lang.org/en/3.0.0/doc/syntax/pattern_matching_rdoc.html).
If you find the warning at boot annoying (I sure do), you can set `RUBYOPT='-W:no-experimental'` in your environment to silence the nag.

## Basic Usage in Rails

`KeycloakRack` attaches itself as Rack middleware and processes the `Authorization` header passed to the application (if any).

Once it runs, it attaches itself to the rack environment in a number of places,
but the primary entry point is `keycloak:session`:

```ruby
class ApplicationController < ActionController::API
  before_action :authenticate_user!

  # @return [void]
  def authenticate_user!
    # KeycloakRack::Session#authenticate! implements a Dry::Matcher::ResultMatcher
    request.env["keycloak:session"].authenticate! do |m|
      m.success(:authenticated) do |_, token|
        # this is the case when a user is successfully authenticated

        # token will be a KeycloakRack::DecodedToken instance, a
        # hash-like PORO that maps a number of values from the
        # decoded JWT that can be used to find or upsert a user

        attrs = decoded_token.slice(:keycloak_id, :email, :email_verified, :realm_access, :resource_access)

        result = User.upsert attrs, returning: %i[id], unique_by: %i[keycloak_id]

        @current_user = User.find result.first["id"]
      end

      m.success do
        # When allow_unauthenticated_requests is true, or
        # a URI is skipped because of skip_paths, this
        # case will be reached. Requests from here on
        # out should be considered anonymous and treated
        # accordingly

        @current_user = AnonymousUser.new
      end

      m.failure do |code, reason|
        # All authentication failures are reached here,
        # assuming halt_on_auth_failure is set to false
        # This allows the application to decide how it
        # wants to respond

        render json: { errors: [{ message: "Auth Failure" }] }, status: :forbidden
      end
    end
  end
end
```

## Configuration

This gem uses [anyway_config](https://github.com/palkan/anyway_config), which allows you to make use of ENV vars, Rails credentials,
and simple YAML configuration files interchangeably.

At minimum, you must configure `server_url` and `realm_id` to authenticate a user's token against your Keycloak instance.

| Option | ENV | Default Value | Type | Required? | Description  | Example |
| ----                    | -----                           | -----   | ------    | -----    | ------ | ----- |
| `server_url`            | `KEYCLOAK_SERVER_URL`           | `nil`   | `String`  | Required | The base url where your Keycloak server is located. This value can be retrieved in your Keycloak client configuration. | `auth:8080` |
| `realm_id`              | `KEYCLOAK_REALM_ID`             | `nil`   | `String`  | Required | Realm's name (not id, actually) | `master` |
| `token_leeway`          | `KEYCLOAK_TOKEN_LEEWAY`         | `10`    | `Integer` | Optional | Number of seconds a token can expire before being rejected by the API. | `15` | 
| `allow_anonymous`       | `KEYCLOAK_ALLOW_ANONYMOUS`      | `false` | `Boolean` | Optional | Whether to allow anonymous users to access the API. If true, authentication will not provided a decoded token instance | `true` |
| `halt_on_auth_failure`  | `KEYCLOAK_HALT_ON_AUTH_FAILURE` | `true`  | `Boolean` | Optional | Whether to short-circuit when a token is invalid, or otherwise fails (if `allow_anonymous` is false, token-less access counts as a failure). Set this to `false` if you want to handle failures in your application instead. | `false` |
| `cache_ttl`             | `KEYCLOAK_CACHE_TTL`            | `86400` | `Integer` | Optional | Interval (in seconds) to cache public keys from Keycloak. These should not change very often, so 1 day (86400) is the default. | `86400` | 
| `ca_certificate_file`   | `KEYCLOAK_CA_CERTIFICATE_FILE`  | `nil`   | `String`  | Optional | Path to the certificate authority used to validate the Keycloak server certificate | `/credentials/production_root_ca_cert.pem` | 
| `skip_paths`            | _n/a_                           | `{}`    | `Hash`    | Optional | Paths where token validation is skipped | `{ get: %w[/ping], post: [%r,/stats,] }`| 

### Options

Because of `anyway_config`, you can create a file `config/keycloak.yml` to populate most of the settings.

```yml
default: &default
  server_url: "https://keycloak.example.com/auth"
  realm_id: Test

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

[Rails credentials](https://guides.rubyonrails.org/security.html#custom-credentials) under the key `keycloak` will also work:

```yml
keycloak:
  server_url: "https://keycloak.example.com/auth"
  realm_id: "Test"
```

You can also do a more traditional approach in an initializer, but note that any changes here
will _override_ values inherited by anyway_config's approach. It's really only useful for
configuring `skip_paths`, given its support for regular expressions.

```ruby
KeycloakRack.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ENV["KEYCLOAK_REALM_ID"]
  config.skip_paths = {
    get: ["/ping"],
    post: [%r,/api/v1/analytics,]
  }
end
```

## Usage

### Authorizing a realm role

There is a helper service that gets mounted in the Rack environment as `keycloak:authorize_realm`, and works
similarly to the session's authenticate method:

```ruby
class UploadProcessor
  def initialize(app)
   @app = app
  end

  def call(env)
    env["keycloak.authorize_realm"].call("upload_permission") do |m|
      m.success do
        # allow the upload to proceed
      end

      m.failure do
        # fail the response, return 403, etc
      end
    end
  end
end

app = Rack::Builder.app do
  use KeycloakRack::Middleware

  run UploadProcessor
end
```

### Authorizing a resource role

There is also a helper service that gets mounted as `keycloak:authorize_resource`,
for checking resource roles:

```ruby
class WidgetCombobulator
  def initialize(app)
    @app = app
  end

  def call(env)
    env["keycloak.authorize_resource"].call("widgets", "recombobulate") do |m|
      m.success do
        # allow the user to recombobulate the widget
      end

      m.failure do
        # return forbidden, log the attempt, etc
      end
    end
  end
end

app = Rack::Builder.app do
  use KeycloakRack::Middleware

  run WidgetCombobulator
end
```

### Overriding the failure response

The easiest approach would be to set `halt_on_auth_failure` to `false` and handle the failure in your application,
but the middleware has a few spots that can be hooked into with a prepended module if you'd prefer to monkey patch.

```ruby
module Patches
  module OverrideKeycloakFailureBody
    # @param [Hash] env
    # @param [Dry::Monads::Failure] monad
    # @return [String, #to_json]
    def build_failure_body(env, monad)
      # You can use the #failure method on the monad to retrieve a tuple
      reason, message, token, original_error = monad.failure

      # reason is a symbol, like :no_token or :expired
      # message is a human-readable string that explains why it failed
      # token is the original token (if any) that was provided
      # original_error is a possible exception that was raised (not all failures have one)

      # Return any object that will JSONify itself with #to_json

      {
        error: "You can't sign in because: #{message}"
      }
    end
  end
end

KeycloakRack::Middleware.prepend Patches::OverrideKeycloakFailureBody
```

If you need to return something other than JSON,
or otherwise augment the headers, you can do something like:

```ruby
module Patches
  module OverrideKeycloakFailureHeaders
    # @param [Hash] env
    # @param [Dry::Monads::Failure] monad
    # @return [{ String => String }]
    def build_failure_headers(env, monad)
      {
        "Content-Type" => "application/xml",
        "Special-Header" => "special-value",
      }
    end
  end
end

KeycloakRack::Middleware.prepend Patches::OverrideKeycloakFailureHeaders
```

In the future, this might be customizable, but it's low priority.

## History

What became this gem started out as a slight modification to [keycloak-api-rails](https://github.com/looorent/keycloak-api-rails)
by [looorent](https://github.com/looorent). For authenticating requests a Rails API that must _always_ have a token,
that gem works great and I would recommend it.

As I continued building my application, I had some needs that weren't met by it, namely:

- Anonymous user access—I just need to know if the user is authenticated or not without preventing
  access to the application, I'll handle failures myself.
- Control over auth failures in general (this is still pending, though made easier to monkey-patch)
- Usage outside of Rails—I have some microservices that are rack applications.
- Easier role checking for rack middleware.
- Stricter auth: no query strings. I want my APIs to only support clients that send an `Authorization`
  header with a bearer token.

I ended up rewriting it from scratch, but the logic in this owes a lot to the original author's design.

## Future extensions

- A way to extract custom attributes from the token besides the defaults Keycloak provides,
  presently there's no way to get at those.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scryptmouse/keycloak_rack.
This project is intended to be a safe, welcoming space for collaboration, and contributors are
expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
