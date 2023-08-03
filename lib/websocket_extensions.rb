class WebsocketExtensions
  def self.all
    extensions = []
    extensions << PermessageDeflate.configure(level: RELAY_CONFIG.ws_deflate_level, max_window_bits: RELAY_CONFIG.ws_deflate_max_window_bits) if RELAY_CONFIG.ws_deflate_enabled

    extensions
  end
end
