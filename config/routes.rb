Rails.application.routes.draw do

  root 'static#index'

  get 'auth/twitter/callback' => 'sessions#create'
  get 'auth/failure' => 'sessions#failure'
  get 'signout' => 'sessions#destroy', as: 'signout'

  match "/delayed_job" => DelayedJobWeb, :anchor => false, via: [:get, :post]

  resources :blocks, only: [ :index ]

  resources :lists, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    get 'add', on: :collection
    post 'subscribe', on: :collection
    delete 'unsubscribe', on: :collection
  end

  post 'users/email' => 'users#email'
  get 'users/decline' => 'users#decline'

  namespace :demo do
    resources :lists, only: [ :index, :new ] do
      get 'edit', on: :collection
      get 'add', on: :collection
    end
  end
end
