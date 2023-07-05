source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

gem "rails", "~> 7.0.5"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "rack-cors"

gem "bootsnap", require: false

gem "importmap-rails"
gem "sprockets-rails"

gem "puma", "~> 5.0"
gem "faye-websocket"
gem "pg", "~> 1.1"
gem "redis", "~> 5.0"
gem "hiredis-client"
gem "sidekiq", "~> 7"
gem "sorcery"

gem "bip-schnorr"
gem "json_schemer"

gem "sentry-ruby"
gem "sentry-sidekiq"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "ffaker"
  gem "rspec-rails", "~> 6.0.0"
end

group :development do
  gem "web-console"
  gem "standardrb", require: false
end

group :test do
  gem "simplecov", require: false
end
