# frozen_string_literal: true

module KeycloakRack
  # Dependency injection container for various `KeycloakRack` objects
  #
  # @api private
  # @!visibility private
  class Container
    extend Dry::Container::Mixin

    namespace "keycloak-rack" do
      register :authenticate, memoize: true do
        KeycloakRack::Authenticate.new
      end

      register :decode_and_verify, memoize: true do
        KeycloakRack::DecodeAndVerify.new
      end

      register :http_client, memoize: true do
        KeycloakRack::HTTPClient.new
      end

      register :key_resolver, memoize: true do
        KeycloakRack::KeyResolver.new
      end

      register :wrap_token, memoize: true do
        KeycloakRack::WrapToken.new
      end
    end
  end
end
