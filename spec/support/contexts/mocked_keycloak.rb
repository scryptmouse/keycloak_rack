# frozen_string_literal: true

require_relative "../token_helper"

RSpec.shared_context "with mocked keycloak" do
  let(:config_server_url) { "http://keycloak.example.com/auth" }
  let(:config_realm_id) { "Test" }
  let(:config_allow_unauthenticated_requests) { false }
  let(:config_halt_on_auth_failure) { true }
  let(:config_cache_ttl) { 86_400 }
  let(:config_skip_paths) { {} }
  let(:mocked_config_env) do
    {
      "KEYCLOAK_SERVER_URL" => config_server_url,
      "KEYCLOAK_REALM_ID" => config_realm_id,
      "KEYCLOAK_CACHE_TTL" => config_cache_ttl,
      "KEYCLOAK_ALLOW_UNAUTHENTICATED_REQUESTS" => config_allow_unauthenticated_requests,
      "KEYCLOAK_HALT_ON_AUTH_FAILURE" => config_halt_on_auth_failure
    }
  end

  let(:token_helper) { TokenHelper.new }
  let(:jwks_response) { token_helper.jwks.as_json }

  let(:public_key_url) do
    "#{config_server_url}/realms/#{config_realm_id}/protocol/openid-connect/certs"
  end

  let(:mocked_public_key_response) do
    {
      body: jwks_response.to_json,
      status: 200
    }
  end

  around do |example|
    with_env(mocked_config_env.transform_values(&:to_s)) do
      mocked_config = KeycloakRack::Config.new realm_id: config_realm_id

      mocked_config.skip_paths = config_skip_paths

      KeycloakRack::Container.stub("keycloak-rack.config", mocked_config)

      resolver = KeycloakRack::KeyResolver.new

      KeycloakRack::Container.stub("keycloak-rack.key_resolver", resolver)

      example.run
    end
  ensure
    KeycloakRack::Container.unstub("keycloak-rack.config")
  end

  before do
    stub_request(:get, public_key_url).
      to_return(mocked_public_key_response)
  end

  # @return [void]
  def refresh_public_keys!
    KeycloakRack::Container["keycloak-rack.key_resolver"].refresh!
  end
end
