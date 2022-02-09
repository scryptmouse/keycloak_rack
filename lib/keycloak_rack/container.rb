# frozen_string_literal: true

module KeycloakRack
  # Dependency injection container for various `KeycloakRack` objects
  #
  # @api private
  # @!visibility private
  class Container
    extend Dry::Container::Mixin

    namespace "keycloak-rack" do
      register :config do
        # :nocov:
        KeycloakRack::Config.new
        # :nocov:
      end

      register :authenticate do
        KeycloakRack::Authenticate.new
      end

      register :decode_and_verify do
        KeycloakRack::DecodeAndVerify.new
      end

      register :http_client do
        KeycloakRack::HTTPClient.new
      end

      register :key_fetcher do
        KeycloakRack::KeyFetcher.new
      end

      register :key_resolver, memoize: true do
        # :nocov:
        KeycloakRack::KeyResolver.new
        # :nocov:
      end

      register :read_token do
        KeycloakRack::ReadToken.new
      end

      register :server_url do
        resolve(:config).server_url
      end

      register :skip_authentication do
        KeycloakRack::SkipAuthentication.new
      end

      register :x509_store do
        resolve(:config).build_x509_store
      end

      register :wrap_token do
        KeycloakRack::WrapToken.new
      end
    end
  end
end
