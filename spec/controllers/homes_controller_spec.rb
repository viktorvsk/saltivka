require "rails_helper"

RSpec.describe HomesController, type: :request do
  describe "GET /" do
    it "contains project name" do
      get "/"
      expect(response.body).to include "Welcome to Saltivka!"
    end
  end
end
