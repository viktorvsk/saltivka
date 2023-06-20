# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = {url: ENV["REDIS_URL"]}
end

Sidekiq.configure_client do |config|
  config.redis = {url: ENV["REDIS_URL"]}
  config.logger = nil if Rails.env.test?
end
