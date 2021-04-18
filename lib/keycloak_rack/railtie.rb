# frozen_string_literal: true

module KeycloakRack
  # Railtie that gets autoloaded when Rails is detected in the environment.
  #
  # @api private
  class Railtie < Rails::Railtie
    railtie_name :keycloak_rack

    initializer("keycloak_rack.insert_middleware") do |app|
      app.config.middleware.use(KeycloakRack::Middleware)
    end
  end
end
