# frozen_string_literal: true

module KeycloakRack
  # Fetches the public key for a keycloak installation.
  #
  # @api private
  class KeyFetcher
    include Import[config: "keycloak-rack.config", http_client: "keycloak-rack.http_client"]

    delegate :realm_id, to: :config

    # @return [Dry::Monads::Success({ Symbol => Object })]
    # @return [Dry::Monads::Failure(Symbol, String)]
    def find_public_keys
      http_client.get_json(realm_id, "protocol/openid-connect/certs").or do |(code, reason, response)|
        Dry::Monads::Result::Failure[:invalid_public_keys, "Could not fetch public keys: #{reason.inspect}"]
      end
    end
  end
end
