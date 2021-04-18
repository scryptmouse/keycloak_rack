# frozen_string_literal: true

module KeycloakRack
  # Check if the request should be skipped based on the request method and path.
  #
  # @api private
  # @!visibility private
  class SkipAuthentication
    include Dry::Monads[:result]

    include Import[config: "keycloak-rack.config"]

    delegate :skip_paths, to: :config

    # @return [Dry::Monads::Success(Boolean)]
    def call(env)
      method = env["REQUEST_METHOD"].to_s.downcase
      path   = env["PATH_INFO"]

      return Success(true) if preflight?(method, env)
      return Success(true) if should_skip?(method, path)

      Success(false)
    end

    private

    def should_skip?(method, path)
      method_paths = skip_paths.fetch(method, [])

      method_paths.any? do |path_pattern|
        if path_pattern.kind_of?(Regexp)
          path_pattern.match? path
        else
          path_pattern == path
        end
      end
    end

    def preflight?(method, headers)
      method == "options" && headers["HTTP_ACCESS_CONTROL_REQUEST_METHOD"].present?
    end
  end
end
