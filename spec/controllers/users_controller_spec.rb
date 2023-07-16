require "rails_helper"

RSpec.describe UsersController, type: :request do
  describe "GET /user/new" do
    it "contains Sign Up header" do
      get "/user/new"
      expect(response.body).to include "Sign Up"
    end
  end
end
