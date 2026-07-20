Rails.application.routes.draw do
  get "users/new"
  get "users/create"
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  concern :turbo_fetch do
    patch :turbo_fetch, on: :collection
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "games#index"
  get "games/history", to: "games#history"
  
  resources :games do
    resources :players, only: [:create]
    member do 
      post :start
    end

    member do 
      post :play
    end

    member do
      get :winner
    end
  end

  get "pages/rules", to: "pages#rules"
  resources :pages, only: [:index]

  resources :offlines, only: [:index]

  get "stats", to: "stats#index"
  resources :stats, only: [:index]

  get "users/show", to: "users#show"
  resources :users, only: %i[new create edit update], concerns: %i[turbo_fetch]

  mount GoodJob::Engine => 'good_job'
end
