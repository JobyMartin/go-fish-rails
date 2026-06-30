Rails.application.routes.draw do
  get "users/new"
  get "users/create"
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "games#index"
  get "games/history", to: "games#history"
  resources :games, only: [:index]

  get "pages/rules", to: "pages#rules"
  resources :pages, only: [:index]

  get "stats", to: "stats#index"
  resources :stats, only: [:index]

  resources :users, only: [:new, :create]
end
