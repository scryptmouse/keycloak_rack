# frozen_string_literal: true

RSpec.describe KeycloakRack::SkipAuthentication do
  include Rack::Test::Methods
  include_context "with mocked keycloak"

  before do
    KeycloakRack.configure do |c|
      c.skip_paths = {
        get: ["/ping"],
        post: [%r{\A/foo.+bar}]
      }
    end
  end

  let(:skipper) { described_class.new }

  let(:app) do
    ->(env) do
      result = skipper.call env

      # We treat "skipped" as no content, allowed as ok, and anything else as server error

      status = result.fmap { |x| x ? 204 : 200 }.value_or(500)

      [status, {}, ["HTTP #{status}"]]
    end
  end

  it "skips GET /ping" do
    get "/ping"

    expect(last_response).to be_no_content
  end

  it "skips POST /foo/baz/bar (with a regular expression)" do
    post "/foo/baz/bar"

    expect(last_response).to be_no_content
  end

  it "does not skip anything else" do
    get "/anywhere/else"

    expect(last_response).to be_ok
  end

  it "skips CORS preflight requests" do
    header "Access-Control-Request-Method", "GET"

    options "/anywhere/else"

    expect(last_response).to be_no_content
  end
end
