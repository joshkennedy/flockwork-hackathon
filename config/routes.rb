Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#show"

  resources :workspaces, only: :create
  resource :session, only: :destroy

  get "sign_in/:token", to: "sign_in_links#show", as: :sign_in_link, format: false
  post "sign_in/:token", to: "sign_in_links#create", format: false

  constraints workspace_slug: /[a-z0-9-]+/ do
    get ":workspace_slug", to: "workspaces#show", as: :workspace
    get ":workspace_slug/sign_in", to: "sign_in_requests#new", as: :new_sign_in_request
    post ":workspace_slug/sign_in", to: "sign_in_requests#create", as: :sign_in_requests
    post ":workspace_slug/demo/:role", to: "demo_sessions#create", as: :demo_session
  end
end
