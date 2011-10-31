Minefold::Application.routes.draw do
  root :to => 'home#index'
  get  '/worlds' => 'home#dashboard', :as => :user_root

  # Admin
  get '/admin' => 'admin#index'
  namespace :admin do
    if Rails.env.development?
      namespace :mail do
        mount UserMailer::Preview => 'user'
        mount WorldMailer::Preview => 'world'
      end
    end
  end

  # Static Pages
  { '/plans'    => 'plans',
    '/features' => 'features',
    '/about'    => 'about',
    '/jobs'     => 'jobs',
    '/contact'  => 'contact',
    '/help'     => 'help',
    '/privacy'  => 'privacy',
    '/terms'    => 'terms'
  }.each do |url, name|
    get url => 'high_voltage/pages#show', :id => name, :as => "#{name}_page"
  end

  # Authentication
  devise_for :users, :skip => :all do
    get    '/login' => 'devise/sessions#new', :as => :new_user_session
    post   '/logout' => 'devise/sessions#create', :as => :user_session
    delete '/logout' => 'devise/sessions#destroy', :as => :destroy_user_session

    get  '/signup/check' => 'users#check'
    get  '/signup' => 'users#new', :as => :new_user
    post '/users' => 'users#create', :as => :users
  end

  get  '/worlds/new' => 'worlds#new', :as => :new_world
  post '/worlds' => 'worlds#create', :as => :worlds

  resource :upload, :path => '/worlds/upload', :only => [:new, :create], :path_names => {:new => '/'} do
    get :policy
  end

  resources :orders

  as :user do

    get '/account' => 'users#edit', :as => :edit_user

    resources :users, :path => '/',
                      :only => [:show, :update],
                      :path_names => {:edit => 'account'} do

      resources :worlds, :path => '/', :only => [:show, :edit, :update] do

        member do
          get  :map
          put :play
        end

        resources :wall_items, :only => [:index, :create]
        resources :players, :only => [:index, :create, :destroy] do
          post :ask, :action => :ask, :on => :collection
          post :add, :action => :add, :on => :collection
          get  :search, :action => :search, :on => :collection

          put '/approve/:play_request_id',
            :action => :approve,
            :on => :collection,
            :as => :approve_play_request
        end

        resource :invite, :only => :create

      end
    end

  end
end
