# frozen_string_literal: true

module KeycloakRack
  # Rack middleware that calls {KeycloakRack::Authenticate} to process a keycloak token.
  #
  # Upon successful processing, it populates the following values into the rack environment
  # for consumption later down the stack:
  #
  # - `keycloak:session`: An instance of {KeycloakRack::Session} that serves as the primary interface
  # - `keycloak:authorize_realm`: An instance of {KeycloakRack::AuthorizeRealm} for authorizing realm-level roles
  # - `keycloak:authorize_resource`: An instance of {KeycloakRack::AuthorizeResource} for authorizing resource-level roles
  class Middleware
    include Dry::Monads[:result]

    include Import[authenticate: "keycloak-rack.authenticate", config: "keycloak-rack.config"]

    # @param [#call] app the next component in the rack middleware stack
    def initialize(app, **options)
      super(**options)

      @app = app
    end

    # Process the rack environment and inject the gem's interfaces into it.
    #
    # If the authentication is a monadic failure, and {KeycloakRack::Config#halt_on_auth_failure halt_on_auth_failure}
    # is true, then it will short-circuit with {#authentication_failed}.
    #
    # @param [Hash] env the rack environment
    # @return [Object]
    def call(env)
      result = authenticate.call(env)

      return authentication_failed(env, result) if halt?(result)

      session_opts = { skipped: false, auth_result: result }

      case result
      in Success[:authenticated, decoded_token]
        session_opts[:token] = decoded_token
      in Success[:skipped]
        session_opts[:skipped] = true
      else
        # nothing to do
      end

      env["keycloak:session"] = session = KeycloakRack::Session.new(**session_opts)
      env["keycloak:authorize_realm"] = session.authorize_realm
      env["keycloak:authorize_resource"] = session.authorize_resource

      @app.call(env)
    end

    private

    # Build the authentication failure when short-circuiting.
    #
    # @note See {#build_failure_headers} and {#build_failure_body} for opportunities
    #   to override.
    # @param [Hash] env the rack environment
    # @param [Dry::Monads::Result] monad
    # @return [(Integer, { String => String }, <String>)] rack response
    def authentication_failed(env, monad)
      status = build_failure_status env, monad

      headers = build_failure_headers env, monad

      body = build_failure_body env, monad

      # :nocov:
      body = body.to_json unless body.kind_of?(String)
      # :nocov:

      [
        status,
        headers,
        [ body ]
      ]
    end

    def build_failure_status(env, monad)
      case monad
      in Failure[:no_token, _]
        401
      in Failure[:expired, String, String, Exception]
        403
      in Failure[Symbol, String, String, Exception]
        400
      else
        500
        # nothing to do
      end
    end

    # @todo Make customizable
    # @param [Hash] env the rack environment
    # @param [Dry::Monads::Result] monad
    # @return [{ String => String }]
    def build_failure_headers(env, monad)
      {
        "Content-Type" => "application/json"
      }
    end

    # @todo Make customizable
    # @note Currently uses GraphQL error format.
    # @param [Hash] env the rack environment
    # @param [Dry::Monads::Result] monad
    # @return [String, #to_json]
    def build_failure_body(env, monad)
      _reason, message, _token, _original_error = monad.failure

      {
        errors: [
          {
            message: message,
            extensions: {
              code: "UNAUTHENTICATED"
            }
          }
        ]
      }
    end

    # @param [Dry::Monads::Result] result
    def halt?(result)
      return false unless result.failure?

      config.halt_on_auth_failure?
    end
  end
end
