# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_user!

  # @return [void]
  def authenticate_user!
    request.env["keycloak:session"].authenticate! do |m|
      m.success(:authenticated) do |_, token|
        @current_user = { keycloak_id: token.keycloak_id }
      end

      m.success do
        @current_user = { anonymous: true }
      end

      m.failure do |code, reason|
        render json: { errors: [{ message: "Auth Failure" }] }, status: :forbidden
      end
    end
  end
end
