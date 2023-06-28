require "simplecov"
SimpleCov.start("rails") do
  add_filter "/vendor/"
end

require "schnorr"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/spec"
require "minitest/mock"

REDIS_TEST_CONNECTION = Redis.new(url: ENV["REDIS_URL"])
FAKE_CREDENTIALS = {
  alice: {pk: "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", sk: "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"},
  bob: {pk: "bd3981deb0bf16fb8829d4b07f665fbed0c87697f9e370181ed7b74cff87885e", sk: "332c404ad2deabc1420f7da627227585ea4f2d1565c16ddd3d23caf0ca424322"},
  carl: {pk: "477318cfb5427b9cfc66a9fa376150c1ddbc62115ae27cef72417eb959691396", sk: "777e4f60b4aa87937e13acc84f7abcc3c93cc035cb4c1e9f7a9086dd78fffce1"}
}

NIP_26_TAG = {
  pk: "8e0d3d3eb2881ec137a11debe736a9086715a8c8beeeda615780064d68bc25dd",
  sk: "ee35e8bb71131c02c1d7e73231daa48e9953d329a4b701f7133c8f46dd21139c",
  conditions: "kind=1&created_at>1680000800&created_at<1687949586",
  sig: "d890dc2d9706f0bfeba01a2a67a2b35790ac75dc6b8908dc3cd2a0d1cdf649100c9e4472477819773a3658aa152e6b7a70d6d88e238995de0155c7b1f8623804"
}

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods
  # Run tests in parallel with specified workers

  # TODO: doesn't work with 50+ tests for some reason
  # parallelize(workers: :number_of_processors)

  parallelize(workers: 1)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class Minitest::Spec
  include FactoryBot::Syntax::Methods
end

module MinitestCallbackPlugin
  def before_setup
    REDIS_TEST_CONNECTION.flushdb
    super
  end

  def after_teardown
    super
    REDIS_TEST_CONNECTION.flushdb
  end
end

Minitest::Test.prepend(MinitestCallbackPlugin)
