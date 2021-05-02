# frozen_string_literal: true

RSpec.describe KeycloakRack::Middleware do
  include Rack::Test::Methods

  include_context "with mocked keycloak"
  include_context "with mocked rack application"

  before do
    refresh_public_keys!
  end

  let(:app) do
    ra = rack_application

    Rack::Builder.app do
      use KeycloakRack::Middleware

      run ra
    end
  end

  it "fails with an invalid bearer token" do
    header "Authorization", "Bearer whoops"

    get ?/

    expect(last_response).to be_bad_request
  end

  context "with an anonymous request" do
    context "when unauthenticated requests are allowed" do
      let(:config_allow_anonymous) { true }

      it "works" do
        get ?/

        expect(last_response).to be_ok
      end
    end

    context "when unauthenticated requests are forbidden" do
      it "is unauthorized" do
        get ?/

        expect(last_response).to be_unauthorized
      end
    end
  end

  context "when the token's key id doesn't match expectations" do
    let(:token) { token_helper.build_token with_random_jwk: true }

    before do
      header "Authorization", "Bearer #{token}"
    end

    it "fails" do
      get ?/

      expect(last_response).to be_bad_request
    end
  end

  context "with a valid token" do
    let(:expires_at) { 1.hour.from_now }

    let(:token) { token_helper.build_token expires_at: expires_at }

    let(:leeway_expires) { expires_at + 10 - 1.second }

    let(:expected_partial_rack_environment) do
      {
        "keycloak:session" => a_kind_of(KeycloakRack::Session),
        "keycloak:authorize_realm" => a_kind_of(KeycloakRack::AuthorizeRealm),
        "keycloak:authorize_resource" => a_kind_of(KeycloakRack::AuthorizeResource),
      }
    end

    before do
      header "Authorization", "Bearer #{token}"
    end

    it "sets the expected keys in the rack environment" do
      get ?/

      expect(last_response).to be_ok

      expect(last_rack_environment).to include_json(expected_partial_rack_environment)
    end

    it "fails when expired" do
      Timecop.freeze(expires_at + 1.hour) do
        get ?/
      end

      expect(last_response).to be_forbidden
    end

    it "honors leeway" do
      Timecop.freeze(leeway_expires) do
        get ?/
      end

      expect(last_response).to be_ok
    end

    context "when the keycloak server fails to provide a valid public key" do
      context "when the server returns an error" do
        let(:mocked_public_key_response) do
          {
            body: "Whoops",
            status: 500
          }
        end

        it "fails" do
          get ?/

          expect(last_response).to be_server_error
        end
      end

      context "when the JSON is invalid" do
        let(:mocked_public_key_response) do
          {
            body: "{ foo",
            status: 200
          }
        end

        it "fails" do
          get ?/

          expect(last_response).to be_server_error
        end
      end

      context "when :alg is missing from the keys" do
        let(:jwks_response) do
          super().tap do |h|
            h["keys"].each do |k|
              k.delete("alg")
            end
          end
        end

        it "fails" do
          get ?/

          expect(last_response).to be_server_error
        end
      end
    end
  end

  context "with a skip configuration" do
    let(:config_skip_paths) do
      {
        get: %w[/ping]
      }
    end

    it "skips authentication" do
      get "/ping"

      expect(last_response).to be_ok

      expect(last_response.body).to match(/anonymous/)
    end
  end
end
