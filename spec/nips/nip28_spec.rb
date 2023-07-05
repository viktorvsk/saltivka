require "rails_helper"

RSpec.describe "NIP-28" do
  describe Event do
    it "treats  kind 41 as replaceable" do
      assert build(:event, kind: 41).kinda?(:replaceable)
    end
  end
end
