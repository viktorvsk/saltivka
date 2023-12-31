# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

websocket_server = Rack::Builder.new do |builder|
  builder.use Rack::Cors do
    allow do
      origins "*"
      resource "*", headers: :any, methods: [:get, :post]
    end
  end
  builder.run Nostr::Relay
end

both_apps = lambda do |env|
  if Faye::WebSocket.websocket?(env) || env["HTTP_ACCEPT"] === "application/nostr+json"
    websocket_server.call(env)
  else
    Rails.application.call(env)
  end
end

run both_apps

Rails.application.load_server
