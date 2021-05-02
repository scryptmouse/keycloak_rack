# frozen_string_literal: true

module KeycloakRack
  # Read the bearer token from the `Authorization` token.
  #
  # @api private
  class ReadToken
    include Dry::Monads[:result]

    include Import[config: "keycloak-rack.config"]

    # The pattern to match bearer tokens with.
    BEARER_TOKEN = /\ABearer (?<token>.+)\z/i.freeze

    # @param [Hash, #[]] env
    # @return [Dry::Monads::Success(String)] when a token is found
    # @return [Dry::Monads::Success(nil)] when a token is not found, but unauthenticated requests are allowed
    # @return [Dry::Monads::Failure(:no_token, String)]
    def call(env)
      found_token = read_from env

      return Success(found_token) if found_token.present?

      return Success(nil) if config.allow_anonymous?

      Failure[:no_token, "No JWT provided"]
    end

    private

    # @param [Hash] env the rack environment
    # @option env [String] "HTTP_AUTHORIZATION" the Authorization header
    # @return [String, nil]
    def read_from(env)
      match = BEARER_TOKEN.match env["HTTP_AUTHORIZATION"]

      match&.[](:token)
    end
  end
end
