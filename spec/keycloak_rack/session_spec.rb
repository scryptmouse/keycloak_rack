# frozen_string_literal: true

RSpec.describe KeycloakRack::Session do
  let(:session) { FactoryBot.create :session }

  subject { session }

  context "with a session built from a valid token" do
    it { is_expected.to be_authenticated }

    it { is_expected.not_to be_anonymous }

    it "can authorize realm roles" do
      expect(session.authorize_realm!("foo")).to be_a_success
    end

    it "can authorize resource roles" do
      expect(session.authorize_resource!("widgets", "bar")).to be_a_success
    end
  end

  context "with an anonymous session" do
    let(:session) { FactoryBot.create :session, :anonymous }

    it { is_expected.to be_anonymous }

    it { is_expected.not_to be_authenticated }

    it "can authorize realm roles" do
      expect(session.authorize_realm!("foo")).to be_a_failure
    end

    it "can authorize resource roles" do
      expect(session.authorize_resource!("widgets", "bar")).to be_a_failure
    end
  end
end
