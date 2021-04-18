# frozen_string_literal: true

RSpec.describe KeycloakRack::KeyResolver do
  include_context "with mocked keycloak"

  let(:cache_ttl) { config_cache_ttl }

  let!(:resolver) { described_class.new }

  let(:start_time) do
    Time.local(2021, 4, 3, 0, 0).in_time_zone
  end

  subject { resolver }

  def fetch_keys(at:)
    Timecop.freeze at do
      {
        public_key:   resolver.find_public_keys,
        retrieved_at: resolver.cached_public_key_retrieved_at,
      }
    end
  end

  describe "#find_public_key" do
    context "when there is no public key in cache yet" do
      let!(:public_key) do
        Timecop.freeze start_time do
          resolver.find_public_keys
        end
      end

      it "returns a valid public key" do
        expect(public_key).to be_a_success
      end

      it "sets the current time to the resolver" do
        expect(resolver.cached_public_key_retrieved_at).to eq start_time
      end
    end

    context "when there is already a public key in cache" do
      let!(:first_fetch) do
        fetch_keys at: start_time
      end

      let!(:first_public_key) { first_fetch[:public_key] }

      let!(:first_retrieved_at) { first_fetch[:retrieved_at] }

      context "with no need to refresh it" do
        let(:almost_a_day_later) { start_time + cache_ttl.seconds - 10.seconds }

        let!(:second_fetch) do
          fetch_keys at: almost_a_day_later
        end

        let(:second_public_key) { second_fetch[:public_key] }
        let(:second_retrieved_at) { second_fetch[:retrieved_at] }

        it "returns a valid public key" do
          expect(second_public_key).to be_a_success
        end

        it "does not refresh the public key" do
          expect(second_public_key.value!).to be first_public_key.value!
        end

        it "does not refresh the public key retrieval time" do
          expect(first_retrieved_at).to eq second_retrieved_at
        end
      end

      context "when its TTL has expired" do
        let(:over_a_day_later) { start_time + cache_ttl.seconds + 10.seconds }

        let!(:second_fetch) { fetch_keys at: over_a_day_later }
        let(:second_public_key) { second_fetch[:public_key] }
        let(:second_retrieved_at) { second_fetch[:retrieved_at] }

        it "returns a valid public key" do
          expect(second_public_key).to be_a_success
        end

        it "refreshes the public key" do
          expect(second_public_key.value!).not_to be first_public_key.value!
        end

        it "refreshes the public key retrieval time" do
          expect(first_retrieved_at).not_to eq second_retrieved_at
        end
      end
    end
  end
end
