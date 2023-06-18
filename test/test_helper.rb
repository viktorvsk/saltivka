require "simplecov"
SimpleCov.start("rails") do
  add_filter "/vendor/"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/spec"
require "minitest/mock"

REDIS_TEST_CONNECTION = Redis.new(url: ENV["REDIS_URL"])

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
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
