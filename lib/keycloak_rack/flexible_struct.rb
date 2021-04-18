# frozen_string_literal: true

module KeycloakRack
  # @abstract
  class FlexibleStruct < Dry::Struct
    transform_keys(&:to_sym)

    transform_types do |type|
      # :nocov:
      if type.default?
        type.constructor do |value|
          value.nil? ? Dry::Types::Undefined : value
        end
      else
        type
      end
      # :nocov:
    end
  end
end
