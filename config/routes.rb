Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#show"

  resources :workspaces, only: :create
  get "get_involved", to: "get_involved#show"

  resources :projects, only: %i[ index new create show edit update destroy ] do
    collection do
      get :archived
      get :deleted
    end

    member do
      post :join
      post :mark_done
      post :reopen
      post :archive
      post :unarchive
      patch :transfer_ownership
      post :restore
    end

    resources :schedule_items, except: %i[ index show ]
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
    resources :people, only: %i[index new create edit update]
    resource :profile, only: %i[edit update]
  end
end
