# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "keycloak_rack/version"

Gem::Specification.new do |spec|
  spec.name        = "keycloak_rack"
  spec.version     = KeycloakRack::VERSION
  spec.authors     = ["Alexa Grey"]
  spec.email       = ["devel@mouse.vc"]
  spec.homepage    = "https://github.com/scryptmouse/keycloak_rack"
  spec.summary     = "Rack middleware for validating authorization tokens from Keycloak"
  spec.description = "Rack middleware for validating authorization tokens from Keycloak"
  spec.license     = "MIT"

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.metadata["yard.run"] = "yri"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "activesupport", ">= 4.2"
  spec.add_dependency "anyway_config", ">= 2.1.0", "< 3"
  spec.add_dependency "dry-auto_inject"
  spec.add_dependency "dry-container"
  spec.add_dependency "dry-effects", ">= 0.0.1"
  spec.add_dependency "dry-initializer"
  spec.add_dependency "dry-matcher"
  spec.add_dependency "dry-monads", ">= 1.3.5", "< 2"
  spec.add_dependency "dry-struct", ">= 1", "< 2"
  spec.add_dependency "dry-types", ">= 1", "< 2"
  spec.add_dependency "dry-validation"
  spec.add_dependency "jwt", ">= 2.2.0", "< 4"
  spec.add_dependency "rack", ">= 2.0.0", "< 4"
  spec.add_dependency "zeitwerk", ">= 2.0.0", "< 3"

  spec.add_development_dependency "appraisal2"
  spec.add_development_dependency "benchmark"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake", ">= 13", "< 14"
  spec.add_development_dependency "redcarpet"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop", "1.85.1"
  spec.add_development_dependency "rubocop-factory_bot"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "set"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "yard-junk"

  spec.required_ruby_version = ">= 3.4.0"
end
