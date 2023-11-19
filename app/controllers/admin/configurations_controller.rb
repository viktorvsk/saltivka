class Admin::ConfigurationsController < AdminController
  def show
    @disabled_configurations = RELAY_CONFIG.public_methods(false)
    @max_allowed_connections, @maintenance, @unlimited_ips = MemStore.with_redis do |redis|
      redis.multi do |t|
        t.get("max_allowed_connections")
        t.get("maintenance")
        t.smembers("unlimited_ips")
      end
    end
  end

  def update
    if configuration_params[:name].in?(RelayConfig::DYNAMIC_CONFIGURATION) && MemStore.update_config(configuration_params[:name], configuration_params[:value])
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def configuration_params
    params.require(:configuration).permit(:name, :value)
  end
end
