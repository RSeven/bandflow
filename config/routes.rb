Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  root "bands#index"

  resource :locale, only: :update

  resources :bands do
    resources :musics, except: [ :index ] do
      collection do
        get :search          # iTunes autocomplete
        post :fetch_metadata # Fetch Spotify/lyrics/chords
      end
    end
    resources :setlists do
      resources :setlist_items, only: [ :create, :destroy, :update ]
      member do
        get :present         # Presentation mode
      end
    end
    resources :events, except: [ :index, :show ]
    resources :invitations, only: [ :create, :destroy ] do
      member do
        get :link            # Show shareable link
      end
    end
  end

  # Public invitation acceptance
  get  "invitations/:token", to: "invitations#show",   as: :invitation
  post "invitations/:token", to: "invitations#accept",  as: :accept_invitation

  # Signup
  resource :registration, only: [ :new, :create ]
end
