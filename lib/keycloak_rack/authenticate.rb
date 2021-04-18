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
  #          # When allow_unauthenticated_requests is true, or
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
      config: "keycloak-rack.config",
      key_resolver: "keycloak-rack.key_resolver",
      read_token: "keycloak-rack.read_token",
      skip_authentication: "keycloak-rack.skip_authentication"
    ]

    delegate :token_leeway, to: :config

    # @param [Hash] env the rack environment
    # @return [Dry::Monads::Success(:authenticated, KeycloakRack::DecodedToken)]
    # @return [Dry::Monads::Success(:skipped, String)]
    # @return [Dry::Monads::Success(:unauthenticated)]
    # @return [Dry::Monads::Failure(:expired, String, String, Exception)]
    # @return [Dry::Monads::Failure(:decoding_failed, String, String, Exception)]
    def call(env)
      return Success[:skipped] if yield skip_authentication.call(env)

      token = yield read_token.call env

      return Success[:unauthenticated] if token.blank?

      decoded_token = yield decode_and_verify token

      Success[:authenticated, decoded_token]
    end

    private

    # @param [String] token
    # @return [Dry::Monads::Success(KeycloakRack::DecodedToken)]
    # @return [Dry::Monads::Failure(:expired, String, String, Exception)]
    # @return [Dry::Monads::Failure(:decoding_failed, String, String, Exception)]
    def decode_and_verify(token)
      jwks = yield key_resolver.find_public_keys

      algorithms = yield algorithms_for jwks

      options = {
        algorithms: algorithms,
        leeway: token_leeway,
        jwks: jwks
      }

      payload, headers = JWT.decode token, nil, true, options
    rescue JWT::ExpiredSignature => e
      Failure[:expired, "JWT is expired", token, e]
    rescue JWT::DecodeError => e
      Failure[:decoding_failed, "Failed to decode JWT", token, e]
    else
      Success DecodedToken.new payload.merge(original_payload: payload, headers: headers)
    end

    # @param [{ Symbol => <{ Symbol => String }> }] jwks
    # @return [<String>]
    def algorithms_for(jwks)
      jwks.fetch(:keys, []).map do |k|
        k[:alg]
      end.uniq.compact.then do |algs|
        algs.present? ? Success(algs) : Failure[:no_algorithms, "Could not derive algorithms from JWKS"]
      end
    end
  end
end
