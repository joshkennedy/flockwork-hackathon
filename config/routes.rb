Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  root "landing#show"
  MarketingPage::ALL.reject(&:home?).each do |page|
    get page.path, to: "marketing_pages#show", defaults: { slug: page.slug }, as: page.route_name
  end
  get "robots.txt", to: "landing#robots", format: false
  get "sitemap.xml", to: "landing#sitemap", format: false, defaults: { format: :xml }, as: :sitemap
  get "llms.txt", to: "landing#llms", format: false
  get "sign_up", to: "organizations#new", as: :sign_up

  get "p/:token", to: "public_projects#show", as: :public_project
  get "p/:token/join", to: "guest_sign_ins#new", as: :guest_sign_in
  post "p/:token/join", to: "guest_sign_ins#create"
  get "p/:token/join/code", to: "guest_sign_ins#code", as: :guest_sign_in_code
  post "p/:token/join/code", to: "guest_sign_ins#verify"
  get "p/:token/join/name", to: "guest_sign_ins#name", as: :guest_sign_in_name
  post "p/:token/join/name", to: "guest_sign_ins#finish"
  delete "p/:token/join", to: "guest_sign_ins#destroy", as: :guest_sign_out
  get "go/:link_token", to: "guest_sign_ins#link", as: :guest_sign_in_link, format: false
  post "go/:link_token", to: "guest_sign_ins#open_link", format: false
  post "p/:token/slots/:slot_id/claim", to: "public_slot_claims#create", as: :public_slot_claim
  delete "p/:token/slots/:slot_id/claim", to: "public_slot_claims#destroy"

  resources :organizations, only: :create
  get "get_involved", to: "get_involved#show"
  get "my_tasks", to: redirect("/home", status: 301)
  resource :oversight, only: :show
  resource :settings, only: %i[ show update ]
  # Old homes of what now lives on Settings; links in sent emails still land on the right tab.
  get "digest_preferences", to: redirect("/settings#settings-notifications"), as: :digest_preferences
  get "profile/edit", to: redirect("/settings#settings-details")
  get "icon.svg", to: "icons#show", as: :icon
  resources :notifications, only: :index do
    member do
      patch :mark_read
    end
    collection do
      patch :mark_all_read
    end
  end

  resources :projects, only: %i[ index new create show edit update destroy ] do
    collection do
      get :archived
      get :deleted
      post :start_meal_planner
      post :start_planner
    end

    member do
      post :join
      post :mark_done
      post :reopen
      post :archive
      post :unarchive
      patch :transfer_ownership
      post :restore
      post :enable_public_link
      post :reset_public_link
      post :disable_public_link
      get :mentionable_people, to: "mentionable_people#index"
    end

    resources :schedule_items, except: %i[ index show ] do
      get :calendar, to: "calendar_downloads#schedule_item"
    end
    resources :tasks, except: %i[ index show ] do
      member do
        post :claim
        post :unclaim
        post :mark_done
        post :reopen
      end
    end
    resources :comments, only: :create
    resources :follows, only: :destroy
    resources :slots, except: %i[ index show ] do
      resource :claim, only: %i[ create destroy ], controller: "slot_claims"
      get :calendar, to: "calendar_downloads#slot"
    end
    resource :slot_run, only: %i[ new create ]
    resources :planner_sessions, path: "planner", only: %i[ new create show ] do
      member do
        post :answer
        post :voice_session
        get :voice_instructions
        get :review
        post :skip_to_review
        post :abandon
        patch :suggestion
        post :accept
        post :select_answer
        post :continue_planning
        post :finish_planning
        post :retry_generation
        post :save_and_leave
        patch :pending_item
        patch :planning_details
        patch :meal_setup
      end
    end
    resources :budget_lines, except: %i[ index show ] do
      resource :status, only: %i[ edit update ], controller: "budget_line_statuses"
    end
    resource :message_draft, only: %i[ new create ]
    resources :messages, except: %i[ index show ]
    resources :doc_items, except: %i[ index ] do
      member do
        get :download
      end
    end
    resources :lists, only: %i[ new create ] do
      resources :list_columns, except: %i[ index show ] do
        member do
          patch :move_up
          patch :move_down
        end
      end
      resources :list_rows, except: %i[ index show ] do
        member do
          patch :toggle_checkbox
        end
      end
    end
    get :team, on: :member
    resources :invitations, only: :create
    resources :memberships, only: :destroy
    resources :recipients, only: %i[ new create destroy ]
    resources :notes, only: :create
    resource :debrief, only: %i[ edit update ], controller: "project_debriefs"
    resource :recurrence, only: %i[ edit update ], controller: "project_recurrences"
    resource :duplicate, only: %i[ new create ], controller: "project_duplicates"
    resource :banner, only: %i[ update destroy ], controller: "project_banners"
  end
  resources :invitations, only: :show, param: :token do
    member do
      patch :accept
      patch :decline
    end
  end
  resource :session, only: :destroy
  post "webhooks/sendly", to: "webhooks/sendly#create", format: false

  get "sign_in/:token", to: "sign_in_links#show", as: :sign_in_link, format: false
  post "sign_in/:token", to: "sign_in_links#create", format: false

  get "email_confirmations/:token", to: "email_confirmations#show", as: :email_confirmation, format: false
  post "email_confirmations/:token", to: "email_confirmations#create", format: false

  get "search/people/:id", to: "search#person", as: :search_person
  get "search", to: "search#index"
  get "home", to: "organizations#show", as: :home
  get "sign_in", to: "sign_in_requests#new", as: :new_sign_in_request
  get "check_email", to: "sign_in_requests#check_email", as: :check_email
  post "sign_in", to: "sign_in_requests#create", as: :sign_in_requests
  get "choose_organization", to: "organization_choices#new", as: :new_organization_choice
  post "choose_organization", to: "organization_choices#create", as: :organization_choice
  get "demo", to: "demo_sessions#new", as: :new_demo_session
  post "demo/:role", to: "demo_sessions#create", as: :demo_session
  get "people/import", to: "people/csv_imports#new", as: :new_people_csv_import
  post "people/import", to: "people/csv_imports#create", as: :people_csv_import
  get "directory/planning_center", to: redirect("/settings#settings-directory"), as: :planning_center_directory
  patch "directory/planning_center", to: "directory/planning_center#update"
  post "directory/planning_center/sync", to: "directory/planning_center#sync", as: :sync_planning_center_directory
  resources :people, only: %i[index new create show edit update destroy] do
    resources :notes, only: %i[create edit update destroy]
    resources :check_ins, only: :create
  end
  resource :profile, only: %i[show update] do
    post :suggest_away
    resources :unavailabilities, only: %i[create destroy]
  end
end
