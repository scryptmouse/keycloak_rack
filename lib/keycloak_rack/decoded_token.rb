# frozen_string_literal: true

module KeycloakRack
  # PORO that wraps the result of decoding the JWT into something slightly more usable,
  # with some type-safety and role checking features.
  class DecodedToken < KeycloakRack::FlexibleStruct
    # Mapping used to remap keys from a Keycloak JWT payload into something more legible.
    # @api private
    KEY_MAP = {
      "allowed-origins" => :allowed_origins,
      "auth_time" => :authorized_at,
      "aud" => :audience,
      "azp" => :authorized_party,
      "exp" => :expires_at,
      "iat" => :issued_at,
      "typ" => :type,
    }.with_indifferent_access.freeze

    Audience = Types::Coercible::Array.of(Types::String)

    private_constant :KEY_MAP

    ALIAS_MAP = KEY_MAP.invert.freeze

    transform_keys do |k|
      KEY_MAP[k] || k.to_sym
    end

    # @!attribute [r] sub
    # The user id / subject for the JWT. Corresponds to `user_id` in Keycloak's rest API,
    # and suitable for linking your local user records to Keycloak's.
    # @return [String]
    attribute :sub, Types::String

    # @!attribute [r] realm_access
    # @return [KeycloakRack::RoleMap]
    attribute :realm_access, RoleMap

    # @!attribute [r] resource_access
    # @return [{ String => KeycloakRack::RoleMap }]
    attribute :resource_access, ResourceRoleMap

    # @!attribute [r] email_verified
    # @return [Boolean]
    attribute? :email_verified, Types::Bool

    # @!attribute [r] name
    # @return [String, nil]
    attribute? :name, Types::String.optional

    # @!attribute [r] preferred_username
    # @return [String, nil]
    attribute? :preferred_username, Types::String.optional

    # @!attribute [r] given_name
    # @return [String, nil]
    attribute? :given_name, Types::String.optional

    # @!attribute [r] family_name
    # @return [String, nil]
    attribute? :family_name, Types::String.optional

    # @!attribute [r] email
    # @return [String, nil]
    attribute? :email, Types::String.optional

    # @!group Token Details

    # @!attribute [r] expires_at
    # The `exp` claim
    # @return [Time]
    attribute? :expires_at, Types::Timestamp

    # @!attribute [r] issued_at
    # The `iat` claim
    # @return [Time]
    attribute? :issued_at, Types::Timestamp

    # @!attribute [r] authorized_at
    # The `auth_time` value from Keycloak.
    # @return [Time]
    attribute? :authorized_at, Types::Timestamp

    # @!attribute [r] jti
    # @return [String]
    attribute :jti, Types::String

    # @!attribute [r] audience
    # @return [String]
    attribute :audience, Audience.optional

    # @!attribute [r] type
    # The `typ` claim in the JWT. Keycloak sets this to `"JWT"`.
    # @return [String]
    attribute :type, Types::String

    # @!attribute [r] authorized_party
    # The `azp` claim
    # @return [String]
    attribute? :authorized_party, Types::String

    # @!attribute [r] nonce
    # Cryptographic nonce for the token
    # @return [String]
    attribute? :nonce, Types::String

    # @!attribute [r] scope
    # @return [String]
    attribute? :scope, Types::String

    # @!attribute [r] session_state
    # @return [String]
    attribute? :session_state, Types::String

    # @!attribute [r] locale
    # @return [String, nil]
    attribute? :locale, Types::String.optional

    # @!attribute [r] allowed_origins
    # @return [<String>]
    attribute? :allowed_origins, Types::StringList

    # @!attribute [r] headers
    # The JWT headers, provided for debugging
    # @return [ActiveSupport::HashWithindifferentAccess]
    attribute? :headers, Types::IndifferentHash

    # @!attribute [r] original_payload
    # The original JWT payload, unmodified, for extracting potential additional attributes.
    # @return [ActiveSupport::HashWithIndifferentAccess]
    attribute? :original_payload, Types::IndifferentHash

    # @!endgroup

    alias keycloak_id sub

    alias first_name given_name

    alias last_name family_name

    ALIASES = %i[keycloak_id first_name last_name].freeze

    private_constant :ALIASES

    delegate :attribute_names, to: :class

    # @param [#to_sym] key
    # @raise [KeycloakRack::DecodedToken::UnknownAttribute] if it is an unknown attribute
    # @return [Object]
    def fetch(key)
      key = key.to_sym

      if key.in?(attribute_names)
        self[key]
      elsif key.in?(ALIASES)
        public_send(key)
      elsif key.in?(original_payload)
        original_payload[key]
      else
        raise UnknownAttribute, "Cannot fetch #{key.inspect}"
      end
    end

    # Check if the current user has a certain realm role
    #
    # @param [#to_s] name
    def has_realm_role?(name)
      name.to_s.in? realm_access.roles
    end

    # Check if the user has a certain role on a certain resource.
    #
    # @param [#to_s] resource_name
    # @param [#to_s] role_name
    def has_resource_role?(resource_name, role_name)
      resource_access[resource_name.to_s]&.has_role?(role_name)
    end

    # Extract keys into something hash-like
    #
    # @param [<String, Symbol>] keys
    # @return [ActiveSupport::HashWithIndifferentAccess]
    def slice(*keys)
      keys.flatten!

      keys.each_with_object({}.with_indifferent_access) do |key, h|
        h[key] = fetch(key)
      end
    end

    # An error raised by {KeycloakRack::DecodedToken#fetch} when
    # trying to fetch something the token doesn't know about
    class UnknownAttribute < KeyError; end

    class << self
      # @param [Symbol] key
      # @return [Symbol]
      def maybe_unalias_key(key)
        ALIAS_MAP.fetch(key, key).to_sym
      end
    end
  end
end
