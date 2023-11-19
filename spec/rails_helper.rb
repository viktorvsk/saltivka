require "simplecov"
SimpleCov.start("rails") do
  add_filter "/vendor/"
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
require "rspec/core"
require_relative "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

require "sidekiq/api"

# Add additional requires below this line. Rails is not loaded until this point!

REDIS_TEST_CONNECTION = Redis.new(url: ENV["REDIS_URL"], driver: :hiredis)
SIDEKIQ_REDIS_TEST_CONNECTION = Redis.new(url: ENV["SIDEKIQ_REDIS_URL"], driver: :hiredis)

FAKE_CREDENTIALS = {
  alice: {pk: "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", sk: "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"},
  bob: {pk: "bd3981deb0bf16fb8829d4b07f665fbed0c87697f9e370181ed7b74cff87885e", sk: "332c404ad2deabc1420f7da627227585ea4f2d1565c16ddd3d23caf0ca424322"},
  carl: {pk: "477318cfb5427b9cfc66a9fa376150c1ddbc62115ae27cef72417eb959691396", sk: "777e4f60b4aa87937e13acc84f7abcc3c93cc035cb4c1e9f7a9086dd78fffce1"}
}

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.run_all_when_everything_filtered = true
  config.filter_run(:focus) unless ENV["CI"]

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:each) do
    REDIS_TEST_CONNECTION.flushdb
    SIDEKIQ_REDIS_TEST_CONNECTION.flushdb
    begin
      MemStore.with_redis do |redis|
        redis.pipelined do |pipeline|
          pipeline.select("0")
          pipeline.call(RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" "))
        end
      end
    rescue RedisClient::CommandError => e
      if e.message != "Index already exists"
        raise(e)
      end
    end
  end

  config.after(:each) { REDIS_TEST_CONNECTION.flushdb }

  include FactoryBot::Syntax::Methods
end
