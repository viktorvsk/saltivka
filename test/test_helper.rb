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
  carl: {pk: "09cd08d416b78dd3e1d6c00c9e14087d803df6360fbf0acdb30106ca042ee81e", sk: "6139e65930b1a5384784ad9907b9a3e570eed0424d53764a7db20e0f02b0adb7"}
}

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

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
