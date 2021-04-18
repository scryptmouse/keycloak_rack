# frozen_string_literal: true

RSpec.describe KeycloakRack::DecodedToken do
  let(:instance) { FactoryBot.create :decoded_token }

  describe "#fetch" do
    it "can fetch aliases" do
      expect(instance.fetch(:keycloak_id)).to eq instance.sub
    end

    it "can be used to get custom attributes" do
      expect(instance.fetch(:custom_attribute)).to eq "custom_value"
    end
  end

  describe "#slice" do
    it "can slice attributes and aliases" do
      expect(instance.slice(:email, :first_name)).to include_json(email: instance.email, first_name: instance.given_name)
    end

    it "can slice custom attributes" do
      expect(instance.slice(:custom_attribute)).to include_json(custom_attribute: a_kind_of(String))
    end

    it "raises an error when trying to slice an unknown attribute" do
      expect do
        instance.slice(:heck)
      end.to raise_error KeycloakRack::DecodedToken::UnknownAttribute
    end
  end
end
