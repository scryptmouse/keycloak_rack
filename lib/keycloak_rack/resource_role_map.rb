# frozen_string_literal: true

module KeycloakRack
  # A type to define a map of {RoleMap}s keyed by resource type.
  #
  # @api private
  ResourceRoleMap = Types::Hash.map(Types::String, RoleMap).default { { "account" => {} } }
end
