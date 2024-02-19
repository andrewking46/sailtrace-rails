Rails.application.routes.draw do
  resources :recordings do
    resources :recorded_locations, only: [:create, :index]

    member do
      get   :track
      get   :replay
      patch :end
    end
  end

  resources :races, only: [] do
    scope module: "races" do
      resources :recordings, only: [:index]
    end
  end

  resources :boats
  resources :users
  resources :boat_classes
  resource  :session

  # Route for the 'More' page
  get 'more', to: 'pages#more'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#index"
end
