# frozen_string_literal: true

FactoryBot.define do
  factory :session, class: "KeycloakRack::Session" do
    token { FactoryBot.create :decoded_token }
    skipped { false }
    auth_result { Dry::Monads.Success token }

    initialize_with do
      KeycloakRack::Session.new(**attributes)
    end

    to_create do |instance|
      instance
    end

    trait :anonymous do
      token { nil }
    end
  end
end
