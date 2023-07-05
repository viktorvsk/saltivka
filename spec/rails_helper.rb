require "simplecov"
SimpleCov.start("rails") do
  add_filter "/vendor/"
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

require "sidekiq/api"

# Add additional requires below this line. Rails is not loaded until this point!

REDIS_TEST_CONNECTION = Redis.new(url: ENV["REDIS_URL"], driver: :hiredis)

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

  config.before(:each) { REDIS_TEST_CONNECTION.flushdb }
  config.after(:each) { REDIS_TEST_CONNECTION.flushdb }

  include FactoryBot::Syntax::Methods
end
