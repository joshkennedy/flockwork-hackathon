Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#show"

  get "p/:token", to: "public_projects#show", as: :public_project

  resources :workspaces, only: :create
  get "get_involved", to: "get_involved#show"
  get "my_tasks", to: "my_tasks#index"
  resource :oversight, only: %i[ show update ]
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

    resources :schedule_items, except: %i[ index show ]
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
    end
    resource :slot_run, only: %i[ new create ]
    resources :planner_sessions, path: "planner", only: %i[ new create show ] do
      member do
        post :answer
        post :voice_session
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
      end
    end
    resources :budget_lines, except: %i[ index show ] do
      resource :status, only: %i[ edit update ], controller: "budget_line_statuses"
    end
    resources :messages, except: %i[ index show ]
    resources :doc_items, except: %i[ index show ] do
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
    resource :duplicate, only: %i[ new create ], controller: "project_duplicates"
  end
  resources :invitations, only: :show, param: :token do
    member do
      patch :accept
      patch :decline
    end
  end
  resource :session, only: :destroy

  get "sign_in/:token", to: "sign_in_links#show", as: :sign_in_link, format: false
  post "sign_in/:token", to: "sign_in_links#create", format: false

  scope ":workspace_slug", constraints: { workspace_slug: /[a-z0-9-]+/ } do
    get "/", to: "workspaces#show", as: :workspace
    get "sign_in", to: "sign_in_requests#new", as: :new_sign_in_request
    post "sign_in", to: "sign_in_requests#create", as: :sign_in_requests
    post "demo/:role", to: "demo_sessions#create", as: :demo_session
    get "people/import", to: "people/csv_imports#new", as: :new_people_csv_import
    post "people/import", to: "people/csv_imports#create", as: :people_csv_import
    get "directory/planning_center", to: "directory/planning_center#show", as: :planning_center_directory
    patch "directory/planning_center", to: "directory/planning_center#update"
    post "directory/planning_center/sync", to: "directory/planning_center#sync", as: :sync_planning_center_directory
    resources :people, only: %i[index new create edit update] do
      resources :notes, only: :create
    end
    resource :profile, only: %i[edit update]
  end
end
