require "test_helper"

class MailerTest < ActiveSupport::TestCase
  test "Has configurable default from" do
    assert_equal "admin@nostr.localhost", ApplicationMailer.default[:from]
  end
end
