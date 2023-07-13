Rails.application.routes.draw do
  mount Nostr::Relay, at: "/", constraints: ->(request) { Faye::WebSocket.websocket?(request.env) || request.env["HTTP_ACCEPT"] === "application/nostr+json" }

  root to: "homes#show"

  get "/pay-to-relay", to: "invoices#new"
  get "/payment-successful", to: "homes#payment_successful"
  post "/payment-callback/:provider", to: "invoices#update"

  resources :invoices, only: %i[create]

  resource :session, only: %i[new create destroy]
  resource :homes, only: %i[show]

  namespace :admin do
    resources :trusted_authors, only: %i[index create destroy]
    resources :connections, only: %i[index destroy]
    resources :author_subscriptions, only: %i[index show create destroy]
    resource :configuration, only: %i[show update]
    root to: "connections#index"
  end
end
