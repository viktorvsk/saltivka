class Admin::ConfigurationsController < AdminController
  def show
    @configuration_json = JSON.pretty_generate(RELAY_CONFIG.public_methods(false).map { |config| [config, RELAY_CONFIG.send(config)] }.to_h)
  end
end
