# frozen_string_literal: true

resque_web_constraint = lambda do |request|
  current_user = request.env['warden'].user
  ability = Ability.new current_user
  rv = ability.present? && ability.respond_to?(:admin?) && ability.admin?
  rv
end

Rails.application.routes.draw do
  mount Bulkrax::Engine, at: '/'
  mount BrowseEverything::Engine => '/browse'

  # block Blacklight bookmark routes
  get '/bookmarks', to: 'application#rescue_404'
  post '/bookmarks', to: 'application#rescue_404'
  get '/bookmarks/*all', to: 'application#rescue_404'
  post '/bookmarks/*all', to: 'application#rescue_404'

  mount Blacklight::Engine => '/'

  get '/concern/generic_works/*rest', to: redirect( '/data/concern/data_sets/%{rest}', status: 302 )

  get ':action' => 'hyrax/static#:action', constraints: { action: %r{
                                                                      about|
                                                                      agreement|
                                                                      datacore-documentation-guide|
                                                                      datacore-glossary|
                                                                      file-format-preservation|
                                                                      globus-help|
                                                                      help|
                                                                      how-to-upload|
                                                                      management-plan-text|
                                                                      mendeley|
                                                                      metadata-guidance|
                                                                      prepare-your-data|
                                                                      retention|
                                                                      subject_libraries|
                                                                      support-for-depositors|
                                                                      terms|
                                                                      use-downloaded-data|
                                                                      versions|
                                                                      zotero
                                                                    }x },
      as: :static

  mount Riiif::Engine => 'images', as: :riiif if Hyrax.config.iiif_image_server?
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  if Rails.configuration.authentication_method == "iu"
    devise_for :users, controllers: { sessions: 'users/sessions', omniauth_callbacks: "users/omniauth_callbacks" }, skip: [:passwords, :registration]
    devise_scope :user do
      get('global_sign_out',
          to: 'users/sessions#global_logout',
          as: :destroy_global_session)
      get 'sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
      get 'users/auth/cas', to: 'users/omniauth_authorize#passthru', defaults: { provider: :cas }, as: "new_user_session"
    end
  else
    devise_for :users
  end

  mount Qa::Engine => '/authorities'
  mount Hyrax::Engine, at: '/'
  # mount Hydra::RoleManagement::Engine => '/' # uncomment to expose Role management in UI
  resources :welcome, only: 'index'
  root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new

  namespace :hyrax, path: :concern do
    resources :collections do
      member do
        get    'display_provenance_log'
      end
    end
  end

  namespace :hyrax, path: :concern do
    resources :file_sets do
      member do
        get    'display_provenance_log'
      end
    end
  end

  namespace :hyrax, path: :concern do
    resources :data_sets do
      member do
        # post   'confirm'
        get    'display_provenance_log'
        get    'doi'
        post   'doi'
        post   'globus_download'
        post   'globus_add_email'
        get    'globus_add_email'
        delete 'globus_clean_download'
        post   'globus_download_add_email'
        get    'globus_download_add_email'
        post   'globus_download_notify_me'
        get    'globus_download_notify_me'
        post   'identifiers'
        post   'tombstone'
        post   'zip_download'
      end
    end
  end

  # Permissions routes
  namespace :hyrax, path: :concern do
  resources :permissions, only: [] do
      member do
        get :copy_access
      end
    end
  end

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  constraints resque_web_constraint do
    mount ResqueWeb::Engine => "/resque"
  end

  resources :bookmarks do
    concerns :exportable
    collection do
      delete 'clear'
    end
  end


  get '/provenance_log/(:id)', to: 'provenance_log#show'
  get '/provenance_log_find/', to: 'provenance_log#show'
  post '/provenance_log_find/', to: 'provenance_log#find'
  get '/provenance_log_zip_download/', to: 'provenance_log#show'
  post '/provenance_log_zip_download/', to: 'provenance_log#log_zip_download'
  get '/provenance_log_deleted_works/', to: 'provenance_log#deleted_works'
  post '/provenance_log_deleted_works/', to: 'provenance_log#deleted_works'
  get '/guest_user_message', to: 'guest_user_message#show'

  get '/sda/request/(:collection)/(:object)', to: 'archive#download_request'
  get '/sda/status/(:collection)/(:object)', to: 'archive#status'
  match '/sda/request/:collection/:object', to: 'archive#download_request', constraints: { object: /[^\/]+/ }, via: :get

  # robots.txt and rack attack config forms
  resource :robots, only: [:show, :edit, :update]
  resource :rack_attack, only: [:edit, :update]

  # Send ActionController::RoutingError to 404 page
  # Must be the last route defined
  match '*unmatched', to: 'application#rescue_404', via: :all

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
