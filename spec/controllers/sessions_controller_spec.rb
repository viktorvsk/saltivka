require "rails_helper"

RSpec.describe SessionsController, type: :request do
  describe "GET /session/new" do
    it "contains Sign In header" do
      get "/session/new"
      expect(response.body).to include "Sign In"
    end
  end
end
