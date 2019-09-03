Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  # To see available routes run 'rails routes'

  # Provide default routes (get, post, patch, delete, etc) for the DropToken controller.
  resources :drop_token, defaults: { format: :json } do
    # The API spec lists /drop_token/{gameId}/{playerId} as the route to post a new
    # move. This isn't really rest like, as that route would look like
    # POST /drop_token/{gameId}/moves and would take player id as a param.
    # Create a post route and map it to the Moves controller.
    delete ':player_name', to: "drop_token#remove_player"
    post ':player_id', to: 'moves#create'
    resources :moves, only: %i[index show]
  end
end
