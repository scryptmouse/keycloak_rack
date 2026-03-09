# frozen_string_literal: true

module KeycloakRack
  # Determines whether a given request should skip authentication based on its path and method.
  class SkipPaths
    include Dry::Monads[:result]
    include Dry::Initializer[undefined: false].define -> do
      param :paths, ::KeycloakRack::Types::SkipPaths, default: proc { {} }
    end

    ACRM = "HTTP_ACCESS_CONTROL_REQUEST_METHOD"

    # @note Used in testing this directly.
    # @param [Hash] env the rack environment
    # @return [Dry::Monads::Success(Boolean)]
    def call(env) = skip?(env) ? Success(true) : Success(false)

    # @param [Hash] env the rack environment
    # @option env [String] "REQUEST_METHOD" the HTTP method of the request
    # @option env [String] "PATH_INFO" the path of the request
    # @option env [String] "HTTP_ACCESS_CONTROL_REQUEST_METHOD" the presence of this header indicates a CORS preflight request
    # @return [Boolean]
    def skip?(env)
      method = env["REQUEST_METHOD"].to_s.downcase
      path   = env["PATH_INFO"]

      preflight?(method, env) || should_skip?(method, path)
    end

    private

    # @param [String] method the HTTP method of the request
    # @param [String] path the path of the request
    def should_skip?(method, path)
      method_paths = paths.fetch(method, [])

      method_paths.any? do |path_pattern|
        if path_pattern.kind_of?(Regexp)
          path_pattern.match? path
        else
          path_pattern == path
        end
      end
    end

    # Whether this is a CORS preflight request. We treat all CORS preflight requests as skipped, since they should not require authentication.
    # @param [String] method
    # @param [Hash] headers
    def preflight?(method, headers) = method == "options" && headers.key?(ACRM) && headers[ACRM].present?

    class << self
      # Finesse a SkipPaths instance out of the given configuration, allowing for flexible input.
      #
      # @param [Hash] paths the skip paths configuration
      # @return [KeycloakRack::SkipPaths]
      def call(paths)
        return paths if paths.kind_of?(self)

        new(paths)
      end
    end
  end
end
