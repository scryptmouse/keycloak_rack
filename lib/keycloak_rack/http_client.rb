# frozen_string_literal: true

module KeycloakRack
  # @note Adapted from monadic HTTP client in another project
  # @api private
  class HTTPClient
    include Dry::Monads[:do, :result]

    include Import[config: "keycloak-rack.config", server_url: "keycloak-rack.server_url", x509_store: "keycloak-rack.x509_store"]

    # @param [String] realm_id
    # @param [String] path
    # @return [Dry::Monads::Success(Net::HTTPSuccess)] on a successful request
    # @return [Dry::Monads::Failure(Symbol, String, Net::HTTPResponse)] on a failure
    def get(realm_id, path)
      uri = build_uri realm_id, path

      request = Net::HTTP::Get.new(uri)

      call request
    end

    # @param [String] realm_id
    # @param [String] path
    # @return [Dry::Monads::Success({ Symbol => Object })] on a successful request
    # @return [Dry::Monads::Failure(:invalid_response, String, Net::HTTPResponse)] if the JSON fails to parse
    # @return [Dry::Monads::Failure(Symbol, String, Net::HTTPResponse)] on a failure
    def get_json(realm_id, path)
      response = yield get realm_id, path

      parse_json response
    end

    # @param [Net::HTTPRequest] request
    # @return [Dry::Monads::Success(Net::HTTPSuccess)] on a successful request
    # @return [Dry::Monads::Failure(Symbol, String, Net::HTTPResponse)] on a failure
    def call(request)
      # :nocov:
      return Failure[:invalid_request, "Not a request: #{request.inspect}", nil] unless request.kind_of?(Net::HTTPRequest)

      uri = request.uri

      use_ssl = uri.scheme != "http"
      # :nocov:

      Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl, cert_store: x509_store) do |http|
        response = http.request request

        # :nocov:
        case response
        when Net::HTTPSuccess then Success response
        when Net::HTTPBadRequest then Failure[:bad_request, "Bad Request", response]
        when Net::HTTPUnauthorized then Failure[:unauthorized, "Unauthorized", response]
        when Net::HTTPForbidden then Failure[:forbidden, "Forbidden", response]
        when Net::HTTPNotFound then Failure[:not_found, "Not Found: #{uri}", response]
        when Net::HTTPGatewayTimeout then Failure[:gateway_timeout, "Gateway Timeout", response]
        when Net::HTTPClientError then Failure[:client_error, "Client Error: HTTP #{response.code}", response]
        when Net::HTTPServerError then Failure[:server_error, "Server Error: HTTP #{response.code}", response]
        else
          Failure[:unknown_error, "Unknown Error", response]
        end
        # :nocov:
      end
    end

    private

    # @param [String] realm_id
    # @param [String] path
    # @return [URI]
    def build_uri(realm_id, path)
      string_uri = File.join(server_url, "realms", realm_id, path)

      URI(string_uri)
    end

    # @param [Net::HTTPResponse] response
    # @return [Dry::Monads::Sucess({ Symbol => Object })] the deserialized JSON, should more or less always be a hash
    # @return [Dry::Monads::Failure(:invalid_response, String, Net::HTTPResponse)] if the JSON fails to parse
    def parse_json(response)
      Success JSON.parse response.body, symbolize_names: true
    rescue JSON::ParserError => e
      Failure[:invalid_response, "Response was not valid JSON: #{e.message}", response]
    end
  end
end
