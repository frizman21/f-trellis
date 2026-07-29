Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]
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
  resources :parts, only: [:index, :show]
  resources :part_types, only: [:index, :new, :create, :edit, :update]
  resources :person_organizations,            only: [:show]
  resources :person_organization_details,     only: [:show]
  resources :person_organization_types,       only: [:index, :new, :create, :edit, :update]
  resources :person_people,                   only: [:show]
  resources :person_person_details,           only: [:show]
  resources :person_person_types,             only: [:index, :new, :create, :edit, :update]
  resources :organization_organizations,        only: [:show]
  resources :organization_organization_details, only: [:show]
  resources :organization_organization_types,   only: [:index, :new, :create, :edit, :update]
  resources :part_organizations,              only: [:show]
  resources :part_organization_details,       only: [:show]
  resources :part_organization_types,         only: [:index, :new, :create, :edit, :update]
  resources :part_parts,                      only: [:show]
  resources :part_part_details,               only: [:show]
  resources :part_part_types,                 only: [:index, :new, :create, :edit, :update]
  resources :sources, only: [:index, :show, :new, :create] do
    member do
      post :fetch
      post :crawl
    end
  end
  resources :domains, only: [:index, :edit, :update]
  resources :research_starting_points
  resources :skills, only: [:index, :show, :new, :create, :edit, :update]
  resources :skill_revisions, only: [:show]
  resources :chats, only: [:index, :show]
  resources :models, only: [:index] do
    collection do
      post :refresh
    end
  end
  resources :source_processing_reports, only: [:index, :new, :create]
  get "source_data/:id/download", to: "source_data#download", as: :download_source_datum

  get   "fixture_promotions",                     to: "fixture_promotions#index",  as: :fixture_promotions, defaults: { format: :json }
  patch "fixture_promotions/:resource/:id",       to: "fixture_promotions#update", as: :fixture_promotion,  defaults: { format: :json }

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "people#index"
end
