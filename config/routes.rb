Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  # Dashboard
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Statistics
  get "statistics", to: "statistics#index", as: :statistics

  # Mobile Suits
  resources :mobile_suits

  # Users (Admin only)
  resources :users, except: [:show] do
    member do
      post :switch_view
    end
    collection do
      post :clear_view
    end
  end

  # Events
  resources :events do
    resources :matches, only: [:new, :create]
    resources :rotations, only: [:new, :create]
  end

  # Matches
  resources :matches, only: [:index, :show, :edit, :update, :destroy] do
    collection do
      delete :bulk_destroy
    end
  end

  # Rotations
  resources :rotations do
    member do
      post :activate
      post :next_match
      post :record_match
      post :copy_for_next_round
      get :player_view
    end
  end

  # Admin
  namespace :admin do
    resources :imports, only: [:new, :create] do
      collection do
        get 'mobile_suits/new', to: 'imports#new_mobile_suits', as: 'new_mobile_suits'
        post 'mobile_suits', to: 'imports#import_mobile_suits', as: 'import_mobile_suits'
      end
    end
  end
end
