# frozen_string_literal: true

module KeycloakRack
  # A caching resolver that wraps around {KeycloakRack::KeyFetcher} to cache its result
  # for {KeycloakRack::Config#cache_ttl} seconds (default: 1.day)
  #
  # @api private
  class KeyResolver
    include Import[http_client: "keycloak-rack.http_client"]

    # @!attribute [r] cached_public_key_retrieved_at
    # @return [ActiveSupport::TimeWithZone]
    attr_reader :cached_public_key_retrieved_at

    # @!attribute [r] cached_public_keys
    # @return [Dry::Monads::Success({ Symbol => <{ Symbol => String }> })]
    # @return [Dry::Monads::Failure]
    attr_reader :cached_public_keys

    def initialize(**)
      super

      @cached_public_keys = Dry::Monads.Failure("nothing fetched yet")
      @cached_public_key_retrieved_at = 1.year.ago
    end

    # @!attribute [r] cache_ttl
    # @return [Integer]
    def cache_ttl = KeycloakRack.config.cache_ttl

    # @see KeycloakRack::PublicKeyResolver#find_public_keys
    # @return [Dry::Monads::Success({ Symbol => Object })]
    # @return [Dry::Monads::Failure(Symbol, String)]
    def find_public_keys
      fetch! if should_refetch?

      @cached_public_keys
    end

    def has_failed_fetch? = @cached_public_keys.failure?

    def has_outdated_cache? = Time.current > @cached_public_key_expires_at

    # @return [void]
    def refresh!
      fetch!
    end

    def should_refetch? = has_failed_fetch? || has_outdated_cache?

    private

    # @return [void]
    def fetch!
      @cached_public_keys = fetch_public_keys
      @cached_public_key_retrieved_at = Time.current
      @cached_public_key_expires_at = @cached_public_key_retrieved_at + cache_ttl.seconds
    end

    # Fetches the public key for a keycloak installation.
    #
    # @return [Dry::Monads::Success({ Symbol => Object })]
    # @return [Dry::Monads::Failure(Symbol, String)]
    def fetch_public_keys
      http_client.get_json(realm_id, "protocol/openid-connect/certs").or do |(code, reason, response)|
        Dry::Monads::Result::Failure[:invalid_public_keys, "Could not fetch public keys: #{reason.inspect}"]
      end
    end

    def realm_id = KeycloakRack.config.realm_id
  end
end
