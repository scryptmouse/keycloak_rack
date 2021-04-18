# frozen_string_literal: true

module KeycloakRack
  # This serves as the primary interface for interacting with Rack and Rails applications,
  # and an instance gets mounted into `keycloak:session` when the middleware processes.
  class Session
    extend Dry::Initializer

    include Dry::Matcher.for(:authenticate!, with: Dry::Matcher::ResultMatcher)

    option :auth_result, Types.Instance(Dry::Monads::Result)
    option :skipped, Types::Bool, default: proc { false }
    option :token, Types.Instance(KeycloakRack::DecodedToken).optional, optional: true
    option :authorize_realm, Types.Interface(:call), default: proc { KeycloakRack::AuthorizeRealm.new self }
    option :authorize_resource, Types.Interface(:call), default: proc { KeycloakRack::AuthorizeResource.new self }

    delegate :has_realm_role?, :has_resource_role?, to: :token, allow_nil: true

    alias skipped? skipped

    # @return [Dry::Monads::Result]
    def authenticate!
      auth_result
    end

    # @return [Dry::Monads::Result]
    def authorize_realm!(*args)
      authorize_realm.call(*args)
    end

    # @return [Dry::Monads::Result]
    def authorize_resource!(*args)
      authorize_resource.call(*args)
    end

    def authenticated?
      auth_result.success? && token.present?
    end

    def anonymous?
      auth_result.success? && token.blank?
    end
  end
end
