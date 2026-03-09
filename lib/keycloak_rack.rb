# frozen_string_literal: true

require "jwt"
require "uri"
require "date"
require "net/http"
require "zeitwerk"

require "active_support/all"

require "anyway_config"
require "dry/auto_inject"
require "dry/configurable"
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
  extend Dry::Configurable

  DEFAULT_X509_STORE = OpenSSL::X509::Store.new.tap do |store|
    store.set_default_paths
  end.freeze

  setting :server_url

  setting :realm_id

  setting :ca_certificate_file

  setting :skip_paths, default: KeycloakRack::SkipPaths.new, constructor: ->(value) { KeycloakRack::SkipPaths.(value) }

  setting :token_leeway, default: 10, constructor: ->(value) { value.to_i }

  setting :cache_ttl, default: 86_400, constructor: ->(value) { value.to_i }

  setting :halt_on_auth_failure, default: true

  setting :allow_anonymous, default: false

  setting :x509_store, default: DEFAULT_X509_STORE

  class << self
    def _config
      @_config ||= Config.new
    end

    def configure(...)
      super
    ensure
      _config.inherit_from_global_config!
    end

    # @return [void]
    def apply_global_config!
      _config.apply_to_global_config!
    end

    # @api private
    # @note Used in testing.
    # @return [void]
    def refresh_config!
      @_config = Config.new

      apply_global_config!
    end
  end

  # Inherit from the environment / config.
  # :nocov:
  apply_global_config! unless defined?(Rails)
  # :nocov:
end

loader.eager_load

# :nocov:
KeycloakRack::Railtie if defined?(Rails)
# :nocov:
