# frozen_string_literal: true

require "jwt"
require "uri"
require "date"
require "net/http"
require "zeitwerk"

require "active_support/all"

require "anyway_config"
require "dry/auto_inject"
require "dry/container"
require "dry/effects"
require "dry/initializer"
require "dry/matcher"
require "dry/monads"
require "dry/struct"
require "dry/types"
require "dry/validation"

require "dry/monads/result"
require "dry/matcher/result_matcher"

Dry::Types.load_extensions(:monads)

loader = Zeitwerk::Loader.for_gem

loader.do_not_eager_load "#{__dir__}/keycloak_rack/railtie.rb"

loader.inflector.inflect(
  "http_client" => "HTTPClient"
)

loader.setup

# Authorize [Keycloak](https://www.keycloak.org) tokens via {KeycloakRack::Middleware rack middleware}.
module KeycloakRack
  class << self
    include KeycloakRack::WithConfig

    # Configure the gem manually.
    #
    # @note Changes using this format will _overwrite_ values inherited from ENV or config files.
    # @yield [config] configure the gem
    # @yieldparam [KeycloakRack::Config] config
    # @yieldreturn [void]
    # @return [void]
    def configure
      yield config
    end
  end
end

loader.eager_load

# :nocov:
KeycloakRack::Railtie if defined?(Rails)
# :nocov:
