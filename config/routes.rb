Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  # To see available routes run 'rails routes'

  # Provide default routes (get, post, patch, delete, etc) for the DropToken controller.
  resources :drop_token do
    resources :moves, only: %i[index show]
  end
end
