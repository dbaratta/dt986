class DropTokenController < ApplicationController
  # GET /drop_token
  #
  # POST Params:
  #   None
  #
  # Returns
  #   { "games" : ["gameid1", "gameid2"] } and a HTTP 200 Status Code
  def index
    games_in_progress = Game.in_progress

    # We are using JBuilder, however it is mostly focused on building valid JSON
    # output where everything has a key. To get around this we need to supply
    # our view with a basic array of game ID strings only.
    @games = []
    games_in_progress.each do |game|
      @games.push(game.id.to_s)
    end
  end

  # POST /drop_token
  # This creates a new DropToken Game
  #
  # POST Params:
  #   JSON Blob which looks like the following:
  #   {
  #     "players": ["player1", "player2"],
  #     "columns": 4,
  #     "rows": 4
  #   }
  #
  # Returns
  #   Valid Request: {"gameId": "Some unique identifier"} and a HTTP 200 Status Code
  #   Invalid Request: {"error_description": "description of what went wrong"} and a HTTP 400 Status Code
  def create
    errors = validate_create_params

    if !errors
      # Bad user input. Render a 400 status code and a description of the
      # error to the user.
      render json: { errors: errors }, status: 400
    else
      players = []
      params[:players].each do |player|
        players.push(Player.find_or_create_by(name: player))
      end
      game_board = Hash.new
      (0...params[:rows]).each do |index|
        game_board[index] = {}
      end
      current_players = []
      players.each do |player|
        current_players.push(player.id.to_s)
      end
      game = Game.create(finished: false,
                         columns: params[:columns],
                         rows: params[:rows],
                         players: players,
                         board: game_board.to_json,
                         current_players: current_players)
      game.save
      render json: { 'gameId': game.id.to_s }
    end
  end

  # GET /drop_token/:id
  #
  # Returns the current state of a game in progress.
  #
  # Returns
  #   {
  #     "players" : ["player1", "player2"], # Initial list of players.
  #     "state": "DONE/IN_PROGRESS",
  #     "winner": "player1", # in case of a draw, the winner will be null and the state will be DONE.
  #                          # if the game is still in progress this key will not exist.
  #   }
  #
  #   Status Codes:
  #     HTTP 200 - OK
  #     HTTP 400 - Bad / Malformed Request
  #     HTTP 404 - No game found with the specified ID
  def show
    unless params[:id]
      render json: { 'error': "Game ID parameter missing." }, status: 400
      return
    end

    @game = Game.find(params[:id])

    unless @game
      render json: { 'error': "Game not found." }, status: 404
      return
    end

    @initial_players = []
    @game.players.each do |player|
      @initial_players.push(player.name)
    end
  end

  def remove_player
    # Attempt to load the player from the DB
    unless params[:drop_token_id] && params[:player_name]
      render json: { 'error': 'Game or player name param missing.' }, status: 404
      return
    end

    game = Game.find(params[:drop_token_id])
    player = Player.find_by(name: params[:player_name])

    if game.current_players.include?(player.id.to_s)
      game.current_players -= [player.id.to_s]
      if game.current_players.count == 1
        game.finished = true
        game.winner = game.current_players.first
      end
      game.moves.create(player_id: player.id.to_s, move_type: 'DELETE')
      game.save
      render json: "", status: 202
    else
      render json: { 'error': 'Player is not part of this game.' }, status: 404
    end
  end

  private

  def validate_create_params
    errors = []
    # Validate the create params
    # Make sure that rows is:
    #   Present
    #   A number
    #   Meets the minimum game size
    if params[:rows].nil?
      errors.push 'Rows parameter is missing.'
    elsif !params[:rows].is_a? Numeric
      errors.push 'Rows parameter must be a number.'
    elsif params[:rows] < DROP_TOKEN_CONFIG[:min_rows]
      errors.push "Rows parameter is less than the game minimum (#{DROP_TOKEN_CONFIG[:min_rows]})"
    end

    # Make sure that columns is:
    #   Present
    #   A Number
    #   Meets the minimum game size
    if params[:columns].nil?
      errors.push 'Columns parameter is missing.'
    elsif !params[:columns].is_a? Numeric
      errors.push 'Columns parameter must be a number.'
    elsif params[:columns] < DROP_TOKEN_CONFIG[:min_columns]
      errors.push "Columns parameter is less than the game minimum (#{DROP_TOKEN_CONFIG[:min_columns]})"
    end

    # Make sure that player is:
    #   Present
    #   An array
    #   Meets the minimum game size
    if params[:players].nil?
      errors.push 'Players parameter is missing.'
    elsif !params[:players].is_a? Array
      errors.push 'Players parameter must be a array.'
    elsif params[:players].size < DROP_TOKEN_CONFIG[:min_players]
      errors.push "Players parameter is less than the game minimum (#{DROP_TOKEN_CONFIG[:min_players]})"
    end

    return errors if errors.size > 0

    return true
  end
end
