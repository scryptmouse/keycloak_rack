# frozen_string_literal: true

module KeycloakRack
  # A service that allows someone to check if the current token has a resource-level role.
  #
  # It is instantiated in `keycloak:authorize_resource` after the middleware runs.
  #
  # This can greatly simplify access control for rack services (for instance, to gate modifications to a certain type of resource).
  #
  # @example
  #   class WidgetCombobulator
  #     def initialize(app)
  #       @app = app
  #     end
  #
  #     def call(env)
  #       env["keycloak.authorize_resource"].call("widgets", "recombobulate") do |m|
  #         m.success do
  #           # allow the user to recombobulate the widget
  #         end
  #
  #         m.failure do
  #           # return forbidden, log the attempt, etc
  #         end
  #       end
  #     end
  #   end
  class AuthorizeResource
    extend Dry::Initializer

    include Dry::Monads[:result]
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    param :session, Types.Instance(KeycloakRack::Session)

    # Check that the current session has a certain resource role.
    #
    # @see KeycloakRack::DecodedToken#has_resource_role?
    # @param [String] resource_name
    # @param [String] role_name
    # @return [Dry::Monads::Success(:authorized, String)]
    # @return [Dry::Monads::Failure(:unauthorized, String)]
    # @return [Dry::Monads::Failure(:unauthenticated, String)]
    def call(resource_name, role_name)
      if session.has_resource_role?(resource_name, role_name)
        Success[:authorized, resource_name, role_name]
      elsif session.authenticated?
        Failure[:unauthorized, "You do not have #{role_name.to_s.inspect} access on #{resource_name.to_s.inspect}"]
      else
        Failure[:unauthenticated, "You are not authenticated"]
      end
    end
  end
end
