Rails.application.routes.draw do
  get "passkeys/index"
  authenticate :user do
    root "my_pages#show"
    resources :passkeys, only: [:index, :create, :destroy] do
      collection do
        resources :creation_options, only: [:create], module: :passkeys
      end
    end
    
    # Initial passkey setup after signup
    get 'passkey_setup', to: 'users/passkeys/initial_passkeys#show', as: :initial_passkey
    post 'passkey_setup', to: 'users/passkeys/initial_passkeys#create', as: :create_initial_passkey
  end

  # パスワードレス登録フロー
  get 'passwordless_sign_up', to: 'users/passwordless_registrations#new', as: :new_passwordless_registration
  post 'passwordless_sign_up', to: 'users/passwordless_registrations#create', as: :passwordless_sign_up
  get 'passwordless_passkey', to: 'users/passwordless_passkeys#new', as: :new_passwordless_passkey
  post 'passwordless_passkey', to: 'users/passwordless_passkeys#create', as: :passwordless_passkey
  get 'passwordless_passkey/creation_options', to: 'users/passwordless_passkeys#creation_options', as: :passwordless_passkey_creation_options

  get "my_pages/show"
  devise_for :users, controllers: { 
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
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
