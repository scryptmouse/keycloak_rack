# frozen_string_literal: true

module KeycloakRack
  # Wrap the result of {KeycloakRack::DecodeAndVerify#call} in a class that
  # provides a unified interface for introspecting a Keycloak JWT.
  class WrapToken
    include Dry::Monads[:result]

    # @param [Hash] payload
    # @param [Hash] headers
    # @return [Dry::Monads::Success(KeycloakRack::DecodedToken)]
    def call(payload, headers)
      raw_attributes = payload.merge(original_payload: payload, headers: headers)

      Success DecodedToken.new raw_attributes
    rescue Dry::Struct::Error => e
      handle_struct_error e
    rescue StandardError => e
      unknown_failure e
    end

    private

    # @param [Dry::Struct::Error] error
    # @return [Dry::Monads::Failure]
    def handle_struct_error(error)
      cause = error.cause

      case cause
      when Dry::Types::MissingKeyError
        claim = KeycloakRack::DecodedToken.maybe_unalias_key cause.key

        wrap_failure "Missing expected JWT claim: #{claim}", error
      when Dry::Types::SchemaError, Dry::Types::ConstraintError
        # :nocov:
        wrap_failure "Unexpected issue with JWT claim types", error
        # :nocov:
      else
        # :nocov:
        unknown_failure error
        # :nocov:
      end
    end

    # @param [Exception] error
    # @return [Dry::Monads::Failure]
    def unknown_failure(error)
      wrap_failure "An unknown error occurred when decoding the token", error
    end

    # @param [String] message
    # @param [Exception] error
    # @return [Dry::Monads::Failure]
    def wrap_failure(message, error)
      Failure[:decoding_failed, message, error]
    end
  end
end
