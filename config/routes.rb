# Only use hash rockets here please.

Minefold::Application.routes.draw do

  namespace :admin do
    mount Resque::Server.new, :at => "/resque"
  end

  # namespace :api do
  #   resource :session, :only => [:show],  :controller => 'session'
  #   post '/campaign/webhook' => 'campaign#webhook'
  #   resources :photos, :only => [:index, :create]
  #   get 'key' => 'Api#key'
  #   get 'upload-policy' => 'Api#upload_policy'
  # end

  post '/stripe/webhook' => 'stripe#webhook'
  post '/pusher/auth' => 'pusher#auth'

  get '/oembed' => 'o_embed#show', :defaults => { :format => 'json' }


  # Static Pages
  { '/about'   => :about,
    '/help'    => :help,
    '/pricing' => :pricing,
    '/privacy' => :privacy,
    '/terms'   => :terms
  }.each do |url, name|
    get url, :controller => 'pages',:action => name, :as => "#{name}_page"
  end

  # Authentication
  devise_scope :user do
    authenticated do
      root :to => 'users#dashboard', :as => :user_root
    end

    get    '/signin' => 'sessions#new', :as => :new_user_session
    post   '/signin' => 'sessions#create', :as => :user_session
    delete '/signout' => 'sessions#destroy', :as => :destroy_user_session

    get '/account/amnesia' => 'passwords#new', :as => :new_user_password
    post '/account/amnesia' => 'passwords#create', :as => nil
    get '/account/revive' => 'passwords#edit', :as => :edit_user_password
    put '/account/revive' => 'passwords#update', :as => nil

    get  '/signup' => 'users#new', :as => :new_user
    post '/users' => 'users#create', :as => :users

    # get  '/confirm/new' => 'confirmations#new', :as => :new_user_confirmation
    # post '/confirm' => 'confirmations#create', :as => :user_confirmation
    get  '/confirm/:confirmation_token' => 'confirmations#show', :as => :confirmation

    resource(:user,
             :path => '/',
             :except => [:index, :show, :destroy],
             :path_names => {:edit => 'settings'}) do
      get :verify

      # get '/pro' => 'users#pro', :as => :pro_account
      # get '/settings' => 'users#edit', :as => :edit_user
    end

    get '/pro' => 'users#pro', :as => :pro_account
    get '/settings/notifications' => 'users#notifications', :as => :notifications_account
  end

  root :to => 'pages#home'

  devise_for :user,
    :skip => [:sessions, :passwords, :registrations, :confirmations],
    :controllers => { :omniauth_callbacks => "omniauth_callbacks" }

  resource :order, :only => [:create]

  # resources :photos do
  #   get 'lightroom', :on => :collection
  #   put 'lightroom', :action => :update_lightroom, :on => :collection
  #   get :download, :on => :collection
  # end

  resources :worlds, :only => [:index, :new, :create] do
    collection do
      resource :upload, :module => :worlds, :only => [:new, :create] do
        get :instructions
        get :policy
      end
    end
  end

  resources(:players,
            :path => '/',
            :contraints => { :id => /^[\w]{1,16}$/ },
            :only => [:show]) do

    resources(:worlds,
              :path => '/',
              :except => [:index, :new, :create],
              :path_names => {:edit => 'settings'}) do

      put :clone, :on => :member

      scope :module => :worlds do
        resources :players, :controller => :memberships, :only => [:index, :create, :destroy] do
          get  :search, :action => :search, :on => :collection
        end

        resources :membership_requests, :only => [:create, :destroy] do
          put :approve, :on => :member
        end

        resources :comments, :only => [:create]
      end
    end

  end

end
