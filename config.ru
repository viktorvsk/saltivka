# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

map "/" do
  run proc { |env|
    if Faye::WebSocket.websocket?(env) || env["HTTP_ACCEPT"] === "application/nostr+json"
      use Rack::Cors do
        allow do
          origins "*"
          resource "*", headers: :any, methods: [:get, :post]
        end
      end
      Nostr::Relay.call(env)
    else
      Rails.application.call(env)
    end
  }
end

run Rails.application
Rails.application.load_server
