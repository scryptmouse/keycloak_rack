# frozen_string_literal: true

RSpec.describe "Rails integration" do
  include_context "with mocked keycloak"

  before :context do
    skip "Rails isn't tested in this environment" unless defined?(Rails)
  end

  describe "request specs", type: :request do
    it "is unauthorized with header" do
      expect do
        get root_path
      end.not_to raise_error

      expect(response).to be_unauthorized
    end

    context "when a valid token is provided", type: :request do
      let!(:token) { token_helper.build_token }

      let!(:headers) do
        {
          "Authorization" => "Bearer #{token}",
        }
      end

      def make_request!
        get root_path, headers: headers
      end

      it "authenticates as expected" do
        expect do
          make_request!
        end.not_to raise_error

        expect(response).to be_ok

        expect(response.body).to include_json keycloak_id: a_kind_of(String)
      end
    end
  end
end
