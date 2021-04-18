# frozen_string_literal: true

module KeycloakRack
  # dry-rb types for this gem.
  #
  # @see https://dry-rb.org/gems/dry-types
  # @api private
  # @!visibility private
  module Types
    include Dry.Types

    # A type to make indifferent hashes
    #
    # @api private
    IndifferentHash = Types.Constructor(::ActiveSupport::HashWithIndifferentAccess) do |value|
      Types::Coercible::Hash[value].with_indifferent_access
    end

    # A type to validate skip paths
    #
    # @api private
    SkipPaths = Types::Hash.map(
      Types::Coercible::String,
      Types::Array.of(Types::String | Types.Instance(Regexp))
    )

    # A type to make arrays of strings
    StringList = Types::Array.of(Types::String).default { [] }

    # A type to parse timestamps
    # @api private
    Timestamp = Types.Constructor(::Time) do |value|
      # :nocov:
      case value
      when Integer then ::Time.at(value)
      when ::Time then value
      when Types.Interface(:to_time) then value.to_time
      end
      # :nocov:
    end.optional
  end
end
