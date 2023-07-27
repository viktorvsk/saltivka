# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = {url: ENV["REDIS_URL"]}
  config.logger.level = Rails.logger.level
end

Sidekiq.configure_client do |config|
  config.redis = {url: ENV["REDIS_URL"], size: Integer(ENV["RAILS_MAX_THREADS"] || 5)}
  config.logger = nil if Rails.env.test?
end
