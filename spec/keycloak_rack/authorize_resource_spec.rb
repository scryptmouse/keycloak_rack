# frozen_string_literal: true

RSpec.describe KeycloakRack::AuthorizeResource do
  let(:session) { FactoryBot.create :session }

  let(:instance) { session.authorize_resource }

  it "works with an authorized widget role" do
    expect(instance.call("widgets", "bar")).to be_a_success
  end

  it "fails with an unauthorized widget role" do
    expect(instance.call("widgets", "baz")).to be_a_failure
  end

  it "fails with an unknown resource" do
    expect(instance.call("unknown", "bar")).to be_a_failure
  end
end
