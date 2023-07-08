Rails.application.routes.draw do
  mount Nostr::Relay, at: "/", constraints: ->(request) { Faye::WebSocket.websocket?(request.env) || request.env["HTTP_ACCEPT"] === "application/nostr+json" }

  root to: "homes#show"

  resource :session, only: %i[new create destroy]
  resource :homes, only: %i[show]

  namespace :admin do
    resources :trusted_authors, only: %i[index create destroy]
    resources :connections, only: %i[index destroy]
    resource :configuration, only: %i[show update]
    root to: "connections#index"
  end
end
