require "test_helper"

class MailerTest < ActiveSupport::TestCase
  test "Has configurable default from" do
    RELAY_CONFIG.stub(:mailer_default_from, "admin@nostr.com") do
      assert_equal "admin@nostr.com", ApplicationMailer.default[:from]
    end
  end
end
