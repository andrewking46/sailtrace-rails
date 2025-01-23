Rails.application.routes.draw do
  root "pages#index"

  get "more"       => "pages#more"
  get "privacy"    => "pages#privacy"
  get "styleguide" => "pages#styleguide"
  get "up"         => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resources :password_resets, only: %i[new create edit update], param: :reset_token
  resources :users, only: %i[new create]

  resources :races, only: :show do
    scope module: :races do
      resource :replay, only: :show
    end
  end

  resources :recordings, only: [] do
    scope module: :recordings do
      resources :recorded_locations, only: :index
    end
  end

  namespace :my do
    resources :boats
    resources :memberships, only: %i[create destroy]
    resources :recordings, only: %i[index show edit update destroy] do
      scope module: :recordings do
        resources :recorded_locations, only: :index
        resource :speed_map, only: :show
      end
    end
  end

  namespace :admin do
    resources :boat_classes
    resource  :dashboard, only: :show
    resources :recordings, only: %i[index show destroy]
    resources :sailing_teams
    resources :users, only: %i[index show destroy]
    resources :yacht_clubs
  end

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
          resources :course_marks, only: %i[index]
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

  mount ActionCable.server => "/cable"
end
