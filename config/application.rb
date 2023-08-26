require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Saltivka
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.autoload_once_paths << "#{root}/app/settings"
    config.autoload_once_paths << "#{root}/lib"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #

    config.time_zone = "UTC"

    if ENV["SMTP_ADDRESS"].present?
      config.action_mailer.raise_delivery_errors = true
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.smtp_settings = {
        user_name: ENV["SMTP_USERNAME"],
        password: ENV["SMTP_PASSWORD"],
        address: ENV["SMTP_ADDRESS"],
        port: ENV["SMTP_PORT"],
        authentication: :plain,
        enable_starttls_auto: ENV.fetch("SMTP_SSL", true)
      }
      config.action_mailer.default_url_options = {
        host: ENV["DEFAULT_MAILER_HOST"],
        protocol: Rails.env.development? ? :http : :https
      }
    end

    config.active_record.schema_format = :sql

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
