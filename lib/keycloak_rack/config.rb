# frozen_string_literal: true

module KeycloakRack
  # Configuration model for KeycloakRack.
  #
  # Uses [anyway_config](https://github.com/palkan/anyway_config)
  # to permit flexible approaches to configuration.
  class Config < Anyway::Config
    config_name "keycloak"

    env_prefix "KEYCLOAK"

    # @!attribute [rw] server_url
    #
    # The URL of your Keycloak installation. Be sure to include `/auth` if necessary.
    #
    # @note Required config value
    # @return [String]
    attr_config :server_url

    # @!attribute [rw] realm_id
    #
    # The ID of the realm used to authenticate requests.
    #
    # @note Required config value
    # @return [String]
    attr_config :realm_id

    # @!attribute [rw] ca_certificate_file
    # The optional path to the CA Certificate to validate connections to a keycloak server.
    # @return [String, nil]
    attr_config :ca_certificate_file

    # @!attribute [r] skip_paths
    # @return [{ #to_s => <String, Regexp> }]
    attr_config skip_paths: {}

    # @!attribute [rw] token_leeway
    # The number of seconds to allow for tokens to be expired to allow for clock drift.
    #
    # @see https://github.com/jwt/ruby-jwt#expiration-time-claim
    # @return [Integer]
    attr_config token_leeway: 10

    # @!attribute [rw] cache_ttl
    # The interval (in seconds) that cached public keys in {KeycloakRack::KeyResolver} should be cached.
    # @return [Integer]
    attr_config cache_ttl: 86_400

    # @!attribute [rw] halt_on_auth_failure
    # @return [Boolean]
    attr_config halt_on_auth_failure: true

    # @!attribute [rw] allow_unauthenticated_requests
    # @return [Boolean]
    attr_config allow_unauthenticated_requests: false

    # required :server_url, :realm_id

    def cache_ttl=(value)
      super Types::Coercible::Integer[value]
    end

    def skip_paths=(value)
      super Types::SkipPaths[value]
    end

    def token_leeway=(value)
      super Types::Coercible::Integer[value]
    end

    # @api private
    # @!visibility private
    # @return [OpenSSL::X509::Store]
    def build_x509_store
      # :nocov:
      OpenSSL::X509::Store.new.tap do |store|
        store.set_default_paths
        store.add_file(ca_certificate_file) if ca_certificate_file.present?
      end
      # :nocov:
    end
  end
end
