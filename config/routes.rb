Rails.application.routes.draw do
  resources :recordings do
    scope module: :recordings do
      resources :recorded_locations, only: %i[index create]
      resource  :replay, only: :show
      resource  :status, only: :show
    end

    member do
      get   :track
      patch :end
      get   :processing
    end
  end

  resources :races, only: :show do
    scope module: :races do
      # resources :recordings, only: :index
      resource :replay, only: :show
    end
  end

  resources :boats
  resources :users
  resource  :session
  resources :password_resets, only: %i[new create edit update], param: :reset_token

  namespace :api do
    namespace :v1 do
      post :login, to: "sessions#create"
      post :refresh, to: "sessions#refresh"
      delete :logout, to: "sessions#destroy"

      resources :boats
      resources :boat_classes, only: %i[index]
      resources :password_resets, only: %i[create update], param: :reset_token

      resources :races, only: %i[show] do
        scope module: :races do
          resources :recordings, only: %i[index]
        end
      end

      resources :recordings do
        member do
          patch :end
        end

        scope module: :recordings do
          resource  :status, only: :show
          resources :maneuvers, only: :index
          resources :recorded_locations, only: %i[index create]
        end
      end

      namespace :users do
        get :email, to: "emails#show"
      end

      resources :users, only: [ :show, :create, :update, :destroy ]
    end
  end

  namespace :admin do
    resources :boat_classes
    resources :recordings, only: %i[index show destroy]
  end

  # Route for the 'More' page
  get "more", to: "pages#more"

  get "privacy", to: "pages#privacy"

  # Route for the style guide page
  get "styleguide", to: "pages#styleguide"

  mount ActionCable.server => "/cable"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#index"
end
