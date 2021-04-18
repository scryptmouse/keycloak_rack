# frozen_string_literal: true

module KeycloakRack
  # PORO to interface with Keycloak roles.
  class RoleMap < KeycloakRack::FlexibleStruct
    # @!attribute [r] roles
    # @return [<String>]
    attribute :roles, Types::StringList

    # @param [#to_s] name
    def has_role?(name)
      name.to_s.in? roles
    end
  end
end
