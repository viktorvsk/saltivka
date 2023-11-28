source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0.dev"

gem "rails", "~> 7.0.5"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "rack-cors"

gem "bootsnap", require: false

gem "importmap-rails"
gem "sprockets-rails"

gem "puma"
gem "faye-websocket"
gem "permessage_deflate"
gem "pg", "~> 1.1"
gem "redis", "~> 5.0"
gem "hiredis-client"
gem "sidekiq", "~> 7"
gem "sorcery"
gem "pagy"
gem "clockwork"

gem "rbsecp256k1"
gem "json_schemer"

gem "sentry-ruby"
gem "sentry-sidekiq"
gem "newrelic_rpm"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "dotenv-rails"
  gem "factory_bot_rails", "~> 6.2.0" # TODO: https://github.com/thoughtbot/factory_bot_rails/pull/432
  gem "ffaker"
  gem "rspec-rails", "~> 6.0.0"
  gem "rack-mini-profiler"
  gem "memory_profiler"
  gem "stackprof"
  gem "ruby-prof"
end

group :development do
  gem "web-console"
  gem "standardrb", require: false
  gem "foreman"
end

group :test do
  gem "simplecov", require: false
end
