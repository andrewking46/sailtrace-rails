Rails.application.routes.draw do
  resources :recordings do
    resources :recorded_locations, only: [:create]

    scope module: :recordings do
      resources :recorded_locations, only: :index
      resource  :replay, only: :show
    end

    member do
      get   :track
      patch :end
    end
  end

  resources :races, only: :show do
    scope module: :races do
      # resources :recordings, only: :index
      resource  :replay, only: :show
    end
  end

  resources :boats
  resources :users
  resource  :session

  namespace :api do
    namespace :v1 do
      post :login, to: 'sessions#create'
      post :refresh, to: 'sessions#refresh'
      delete :logout, to: 'sessions#destroy'
      resources :recordings, only: [:create, :update, :show] do
        member do
          patch 'end'
        end

        resources :recorded_locations, only: [:create] do
          collection do
            post :batch, to: 'recorded_locations#batch_create'
          end
        end
      end
    end
  end

  scope module: :admin do
    resources :boat_classes
  end

  # Route for the 'More' page
  get 'more', to: 'pages#more'

  # Route for the style guide page
  get 'styleguide', to: 'pages#styleguide'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#index"
end
