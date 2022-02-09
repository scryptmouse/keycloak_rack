# frozen_string_literal: true

module KeycloakRack
  # Accept an encoded JWT and return the raw token.
  class DecodeAndVerify
    include Dry::Monads[:do, :result]

    include Import[
      config: "keycloak-rack.config",
      key_resolver: "keycloak-rack.key_resolver",
    ]

    delegate :token_leeway, to: :config

    # @param [String] token
    # @return [Dry::Monads::Success(Hash, Hash)] a tuple of the JWT payload and its headers
    # @return [Dry::Monads::Failure(:expired, String, String, Exception)]
    # @return [Dry::Monads::Failure(:decoding_failed, String, Exception)]
    def call(token)
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
      Failure[:decoding_failed, "Failed to decode JWT", e]
    else
      Success[payload, headers]
    end

    private

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
