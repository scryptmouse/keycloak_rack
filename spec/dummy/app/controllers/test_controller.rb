# frozen_string_literal: true

class TestController < ApplicationController
  def root
    render json: @current_user
  rescue StandardError => e
    render json: { error: e, backtrace: e.backtrace }, status: :internal_server_error
  end
end
