# frozen_string_literal: true

RSpec.describe KeycloakRack::AuthorizeRealm do
  let(:session) { FactoryBot.create :session }

  let(:instance) { session.authorize_realm }

  it "works with an authorized realm role" do
    expect(instance.call("foo")).to be_a_success
  end

  it "fails with an unauthorized realm role" do
    expect(instance.call("bar")).to be_a_failure
  end
end
