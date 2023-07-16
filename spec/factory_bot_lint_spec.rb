# frozen_string_literal: true

require "rails_helper"

RSpec.describe(FactoryBot) do
  it "successfully creates all models" do
    expect { described_class.lint }.not_to(raise_exception)
  end
end
