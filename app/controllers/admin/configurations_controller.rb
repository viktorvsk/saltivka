class Admin::ConfigurationsController < AdminController
  DYNAMIC_CONFIGURATION = %w[maintenance max_allowed_connections]

  def show
    @disabled_configurations = RELAY_CONFIG.public_methods(false)
    @max_allowed_connections, @maintenance = Sidekiq.redis do |connection|
      connection.multi do |t|
        t.get("max_allowed_connections")
        t.get("maintenance")
      end
    end
  end

  def update
    if configuration_params[:name].in?(DYNAMIC_CONFIGURATION) && Sidekiq.redis { |c| c.set(configuration_params[:name].to_s, configuration_params[:value].to_s) }
      head :ok
    else
      head :unprocessible_entity
    end
  end

  private

  def configuration_params
    params.require(:configuration).permit(:name, :value)
  end
end
