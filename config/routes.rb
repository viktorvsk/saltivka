require "sidekiq/web"
require "admin_constraint"

Rails.application.routes.draw do
  mount Nostr::Relay, at: "/", constraints: ->(request) { Faye::WebSocket.websocket?(request.env) || request.env["HTTP_ACCEPT"] === "application/nostr+json" }
  mount Sidekiq::Web => "/sidekiq", :constraints => AdminConstraint.new, :as => :sidekiq

  root to: "homes#show"

  get "/pay-to-relay", to: "invoices#new"
  get "/payment-successful", to: "homes#payment_successful"
  post "/payment-callback/:provider", to: "invoices#update"

  resources :invoices, only: %i[create]

  resource :session, only: %i[new create destroy]
  resource :homes, only: %i[show]
  resource :user, only: %i[new edit create update show] do
    resources :user_pubkeys, only: %i[create destroy update], on: :collection, as: :pubkeys
  end
  resources :email_confirmations, only: %i[show create]
  resources :password_resets, only: %i[create edit update new]

  namespace :admin do
    resources :trusted_authors, only: %i[index create destroy]
    resources :connections, only: %i[index destroy]
    resources :author_subscriptions, only: %i[index show create destroy]
    resources :relay_mirrors, except: %i[show edit update] do
      put :activate, on: :member
      put :deactivate, on: :member
    end
    resource :configuration, only: %i[show update]
    root to: "connections#index"
  end
end
