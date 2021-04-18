# frozen_string_literal: true

FactoryBot.define do
  factory :decoded_token, class: "KeycloakRack::DecodedToken" do
    data { {} }
    expires_at { 3.hours.from_now }
    issued_at { Time.current }
    leeway { 10 }

    initialize_with do
      TokenHelper.new.build_decoded_token(**attributes)
    end

    to_create do |instance|
      instance
    end
  end
end
