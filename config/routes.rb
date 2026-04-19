Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :people, only: [:index, :show]
  resources :person_types, only: [:index, :new, :create, :edit, :update]
  resources :organizations, only: [:index, :show]
  resources :organization_types, only: [:index, :new, :create, :edit, :update]
  resources :facilities, only: [:index, :show]
  resources :facility_types, only: [:index, :new, :create, :edit, :update]
  resources :sources, only: [:index, :show, :new, :create] do
    member do
      post :fetch
    end
  end
  resources :skills, only: [:index, :show, :new, :create, :edit, :update]
  resources :skill_revisions, only: [:show]
  get "source_data/:id/download", to: "source_data#download", as: :download_source_datum

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "people#index"
end
