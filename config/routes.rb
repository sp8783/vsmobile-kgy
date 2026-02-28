Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions"
  }

  # Guest login
  devise_scope :user do
    post "users/guest", to: "users/sessions#guest", as: :guest_login
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Push notifications
  get "vapid_public_key", to: "push_subscriptions#vapid_public_key"
  resources :push_subscriptions, only: [ :create, :destroy ] do
    collection do
      delete :unsubscribe_all
    end
  end

  # Defines the root path route ("/")
  root "dashboard#index"

  # Dashboard
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Profile (User settings)
  resource :profile, only: [ :edit, :update ]

  # Statistics
  get "statistics", to: "statistics#index", as: :statistics

  # API
  namespace :api do
    resources :events, only: [] do
      member do
        post :timestamps
        post :notify_failure
        post :stats
      end
    end
  end

  # Events
  resources :events do
    member do
      get :edit_timestamps
      patch :update_timestamps
      post :trigger_analysis
    end
    resources :matches, only: [ :new, :create ]
    resources :rotations, only: [ :new, :create ]
  end

  # Matches
  resources :matches, only: [ :index, :show, :edit, :update, :destroy ] do
    collection do
      delete :bulk_destroy
    end
    resources :reactions, only: [] do
      collection do
        post :toggle
      end
    end
    resource :stats, controller: "match_stats", only: [ :edit, :update, :destroy ]
  end

  # Rotations
  resources :rotations do
    member do
      post :activate
      post :deactivate
      post :next_match
      post :go_to_match
      post :record_match
      post :update_match_record
      post :copy_for_next_round
      # get :player_view  # Deprecated: Player view is now integrated into the dashboard
    end
  end

  # Announcements
  resources :announcements, only: [] do
    member do
      post :mark_as_read
    end
  end

  # Admin
  namespace :admin do
    resources :announcements, except: [ :show ]
    resources :users, except: [ :show ] do
      member do
        post :switch_view
      end
      collection do
        post :clear_view
      end
    end
    resources :mobile_suits, except: [ :show ]
    resources :master_emojis, except: [ :show ]
    resources :imports, only: [ :new, :create ] do
      collection do
        get "mobile_suits/new", to: "imports#new_mobile_suits", as: "new_mobile_suits"
        post "mobile_suits", to: "imports#import_mobile_suits", as: "import_mobile_suits"
      end
    end
  end
end
