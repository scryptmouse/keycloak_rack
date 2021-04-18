# frozen_string_literal: true

module KeycloakRack
  # Adds `config` as a property without using {KeycloakRack::Import},
  # for instances where dependency injection doesn't make sense.
  #
  # @!visibility private
  module WithConfig
    # @!attribute [r] config
    # @return [KeycloakRack::Config]
    def config
      KeycloakRack::Container["keycloak-rack.config"]
    end
  end
end
