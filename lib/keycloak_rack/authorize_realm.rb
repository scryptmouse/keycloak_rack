# frozen_string_literal: true

module KeycloakRack
  # A service that allows someone to check if the current token has a realm-level role.
  #
  # It is instantiated in `keycloak:authorize_realm` after the middleware runs.
  #
  # This can greatly simplify access control for rack services (for instance, to gate uploading files outside of Rails).
  #
  # @example
  #   class UploadProcessor
  #     def initialize(app)
  #       @app = app
  #     end
  #
  #     def call(env)
  #       env["keycloak.authorize_realm"].call("upload_permission") do |m|
  #         m.success do
  #           # allow the upload to proceed
  #         end
  #
  #         m.failure do
  #           # fail the response, return 403, etc
  #         end
  #       end
  #     end
  #   end
  class AuthorizeRealm
    extend Dry::Initializer

    include Dry::Monads[:result]
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    param :session, Types.Instance(KeycloakRack::Session)

    # Check to see if the current user session has a certain realm-level role.
    #
    # @see KeycloakRack::DecodedToken#has_realm_role?
    # @param [String] role_name
    # @return [Dry::Monads::Success(:authorized, String)]
    # @return [Dry::Monads::Failure(:unauthorized, String)]
    # @return [Dry::Monads::Failure(:unauthenticated, String)]
    def call(role_name)
      if session.has_realm_role?(role_name)
        Success[:authorized, role_name]
      elsif session.authenticated?
        Failure[:unauthorized, "You do not have #{role_name.to_s.inspect} access"]
      else
        Failure[:unauthenticated, "You are not authenticated"]
      end
    end
  end
end
