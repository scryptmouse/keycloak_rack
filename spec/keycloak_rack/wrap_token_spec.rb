# frozen_string_literal: true

RSpec.describe KeycloakRack::WrapToken do
  let(:operation) { described_class.new }

  context "when providing invalid values" do
    it "fails correctly with nil values" do
      expect(operation.(nil, nil)).to be_failure
    end

    it "fails correctly with empty hashes" do
      expect(operation.({}, {})).to be_failure
    end
  end
end
