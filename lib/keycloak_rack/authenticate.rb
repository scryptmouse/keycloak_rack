# frozen_string_literal: true

module KeycloakRack
  # The core service that handles authenticating a request from Keycloak.
  #
  # @example
  #  class ApplicationController < ActionController::API
  #    before_action :authenticate_user!
  #
  #    # @return [void]
  #    def authenticate_user!
  #      # KeycloakRack::Session#authenticate! implements a Dry::Matcher::ResultMatcher
  #      request.env["keycloak:session"].authenticate! do |m|
  #        m.success(:authenticated) do |_, token|
  #          # this is the case when a user is successfully authenticated
  #
  #          # token will be a KeycloakRack::DecodedToken instance, a
  #          # hash-like PORO that maps a number of values from the
  #          # decoded JWT that can be used to find or upsert a user
  #
  #          attrs = decoded_token.slice(:keycloak_id, :email, :email_verified, :realm_access, :resource_access)
  #
  #          result = User.upsert attrs, returning: %i[id], unique_by: %i[keycloak_id]
  #
  #          @current_user = User.find result.first["id"]
  #        end
  #
  #        m.success do
  #          # When allow_anonymous is true, or
  #          # a URI is skipped because of skip_paths, this
  #          # case will be reached. Requests from here on
  #          # out should be considered anonymous and treated
  #          # accordingly
  #
  #          @current_user = AnonymousUser.new
  #        end
  #
  #        m.failure do |code, reason|
  #          # All authentication failures are reached here,
  #          # assuming halt_on_auth_failure is set to false
  #          # This allows the application to decide how it
  #          # wants to respond
  #
  #          render json: { errors: [{ message: "Auth Failure" }] }, status: :forbidden
  #        end
  #      end
  #    end
  #  end
  class Authenticate
    include Dry::Monads[:do, :result]

    include Import[
      decode_and_verify: "keycloak-rack.decode_and_verify",
      wrap: "keycloak-rack.wrap_token",
    ]

    # The pattern to match bearer tokens with.
    BEARER_TOKEN = /\ABearer (?<token>.+)\z/i

    delegate :skip?, to: :skip_paths

    # @param [Hash] env the rack environment
    # @return [Dry::Monads::Success(:authenticated, KeycloakRack::DecodedToken)]
    # @return [Dry::Monads::Success(:skipped, String)]
    # @return [Dry::Monads::Success(:unauthenticated)]
    # @return [Dry::Monads::Failure(:expired, String, String, Exception)]
    # @return [Dry::Monads::Failure(:decoding_failed, String, Exception)]
    def call(env)
      return Success[:skipped] if skip?(env)

      token = yield read_token(env)

      return Success[:unauthenticated] if token.blank?

      payload, headers = yield decode_and_verify.call token

      decoded_token = yield wrap.call payload, headers

      Success[:authenticated, decoded_token]
    end

    # @!attribute [r] skip_paths
    # @see KeycloakRack::SkipPaths#skip?
    def skip?(env) = KeycloakRack.config.skip_paths.skip?(env)

    private

    # @param [Hash, #[]] env
    # @return [Dry::Monads::Success(String)] when a token is found
    # @return [Dry::Monads::Success(nil)] when a token is not found, but unauthenticated requests are allowed
    # @return [Dry::Monads::Failure(:no_token, String)]
    def read_token(env)
      found_token = read_from env

      return Success(found_token) if found_token.present?

      return Success(nil) if KeycloakRack.config.allow_anonymous

      Failure[:no_token, "No JWT provided"]
    end

    # @param [Hash] env the rack environment
    # @option env [String] "HTTP_AUTHORIZATION" the Authorization header
    # @return [String, nil]
    def read_from(env)
      match = BEARER_TOKEN.match env["HTTP_AUTHORIZATION"]

      match&.[](:token)
    end
  end
end
