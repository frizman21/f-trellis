Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise owns /users/sign_in and friends and is declared above, so it matches
  # first; this adds only the index beside it.
  resources :users, only: [:index]

  # A project has two sides: the ontology it describes things with, and the data
  # recorded against it. Both live under the project — with everything scoped, a
  # top-level ontology screen would have no project to show.
  resources :projects, only: [:index, :show, :new, :create, :edit, :update] do
    # A project's data view is the project itself; its structure has its own
    # address.
    member do
      get :structure
      get :ai_configuration
    end

    # Index actions live at :ontology and :data above; these carry the records.
    # Attributes are edited on their type's own form, so they have no screens of
    # their own — two places to add an attribute is how the two drift.
    resources :entity_types, except: [:index]
    resources :relationship_types, except: [:index]
    # Declared before the ":type_slug" catch-all below, which would otherwise
    # swallow it. destroy removes the join, not the page — see the controller.
    resources :sources, only: [:index, :show, :new, :create, :destroy], module: :projects do
      member { post :extract }
    end

    resources :entities, except: [:index]
    resources :relationships, only: [:create, :edit, :update, :destroy]

    # A project's entities of one kind, at the type's own slug — /projects/1/
    # rocket-engines. Declared last so every named route above wins the match
    # first; EntityType additionally refuses a slug that would collide with one,
    # because route ordering alone would let such a type save and then be
    # unreachable.
    # The constraint is what keeps this from swallowing the project's own member
    # routes: without it "/projects/1/edit" matches here with type_slug "edit"
    # and 404s as an unknown entity type. Driven by the same list EntityType
    # validates against, so a word cannot be taken by a route and free for a
    # type at the same time.
    get ":type_slug", to: "entities#index", as: :typed_entities,
        constraints: ->(request) {
          EntityType::RESERVED_SLUGS.exclude?(request.path_parameters[:type_slug])
        }
  end

  resources :sources, only: [:index, :show, :new, :create] do
    collection do
      # Backs the source search field on the ontology's CRUD forms. A select of
      # every source is not an option: a crawled deployment has thousands.
      get :search
    end
    member do
      post :fetch
      post :crawl
      get :links_from
      get :links_to
      get :triage
      post :triage, action: :run_triage
      post :add_to_learning_set
    end
  end
  resources :source_imports, only: [ :index, :new, :create, :show ]
  resources :learning_sets do
    member do
      post :add_source
      delete :remove_source
    end
  end
  resources :domains, only: [:index, :show, :edit, :update]
  resources :source_exclusions, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :research_starting_points
  resources :skills, only: [:index, :show, :new, :create, :edit, :update]
  # Singular: one triage step, one configuration.
  resource :triage_configuration, only: [:show, :update]
  resources :skill_revisions, only: [:show]
  resources :skill_evaluations, only: [:index, :show, :new, :create, :edit, :update] do
    member do
      post :run
    end
    collection do
      # The models section of the form, on its own — a collection route because
      # it serves the new form too, where there is no evaluation to hang it off.
      get :model_slate
    end
  end
  resources :skill_evaluation_results, only: [:show]
  resources :chats, only: [:index, :show]
  resources :models, only: [:index, :edit, :update] do
    collection do
      post :refresh
    end
  end
  resources :source_processing_reports, only: [:index, :new, :create]
  get "source_data/:id/download", to: "source_data#download", as: :download_source_datum
  post "source_data/:id/extract_links", to: "source_data#extract_links", as: :extract_links_source_datum

  get   "fixture_promotions",                     to: "fixture_promotions#index",  as: :fixture_promotions, defaults: { format: :json }
  patch "fixture_promotions/:resource/:id",       to: "fixture_promotions#update", as: :fixture_promotion,  defaults: { format: :json }

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "projects#index"
end
