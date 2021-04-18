# frozen_string_literal: true

RSpec.shared_context "with mocked rack application" do
  attr_reader :last_rack_environment

  let(:base_app_implementation) do
    ->(env) do
      @last_rack_environment = env

      state = env["keycloak:session"].authenticate! do |m|
        m.success(:authenticated) do
          "authenticated"
        end

        m.success do
          "anonymous"
        end

        m.failure do
          "failed"
        end
      end

      response = {
        "auth_state" => state
      }

      [
        200,
        { "Content-Type" => "application/json" },
        [response.to_json]
      ]
    end
  end

  let(:rack_application) do
    base_app_implementation.tap do |app|
      allow(app).to receive(:call).and_call_original
    end
  end
end
