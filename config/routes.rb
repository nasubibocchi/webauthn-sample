Rails.application.routes.draw do
  get "passkeys/index"
  authenticate :user do
    root "my_pages#show"
    resources :passkeys, only: [:index, :create, :destroy] do
      collection do
        resources :creation_options, only: [:create], module: :passkeys
      end
    end
  end

  get "my_pages/show"
  devise_for :users, controllers: { sessions: 'users/sessions' }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  post 'passkeys/request_options', to: 'passkeys/request_options#create', as: :request_options
  get 'passkeys/poll_status', to: 'passkeys/auth_status#show', as: :poll_auth_status

  # Defines the root path route ("/")
  # root "posts#index"

  scope :passkeys do
    resources :request_options, only: [:create], module: :passkeys
  end

  devise_scope :user do
    delete 'logout', to: 'devise/sessions#destroy'
  end
end
