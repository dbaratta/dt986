class MovesController < ApplicationController
  def index
    load_game
    @moves = @game.moves

    if params[:start] && params[:until]
      @moves = @moves.slice(params[:start].to_i..params[:until].to_i)
    end
  end

  def show
    load_game
    @move = @game.moves.find(params[:id])
  end

  def create
    return unless load_game
    return unless load_player

    # Validate that the player can move.
    return unless validate_move

    # Make sure that the player isn't trying to move to an full column
    game_board = JSON.parse @game.board
    game_board.default = {}
    return render json: { 'error': 'Column is full' }, status: 400 if game_board[params[:column].to_s][(@game.rows - 1).to_s]

    (0...@game.rows).each do |index|
      next unless game_board[params[:column].to_s][index.to_s].nil?

      # We found a open spot. Update it with the players ID so we can check for winners.
      game_board[params[:column].to_s][index.to_s] = @player.id.to_s
      @game.last_player_move = @player.id
      @game.board = game_board.to_json
      @game.moves.create(player_id: @player.id.to_s, move_type: 'MOVE', column: params[:column])
      @game.save

      render json: { 'move': "#{@game.id.to_s}/moves/#{@game.moves.last.id.to_s}" }

      if check_for_winner(params[:column], index)
        # Someone won. Update the game state accordingly.
        @game.finished = true
        @game.winner = @player.id.to_s
        @game.save
      else
        max_moves = @game.columns * @game.rows
        if @game.moves.where(move_type: 'MOVE').count >= max_moves
          @game.finished = true
          @game.save
        end
      end


      break
    end

  end

  private

  def load_game
    @game = Game.find(params[:drop_token_id])
    unless @game
      render json: { 'error': 'Game not found' }, status: 404
      return false
    end

    true
  end

  def load_player
    @player = Player.find_by(name: params[:player_id])
    if @player.nil?
      render json: { 'error': 'Player not found' }, status: 404
      return false
    end

    true
  end

  def validate_move
    # Validate input (make sure we can find the game, player and that the player
    # is a part of the game.)

    if @game.players.where(name: @player.name).size.zero?
      render json: { 'error': 'Player is not part of game.' }, status: 404
      return false
    end

    if !params[:column].present? || !params[:column].is_a?(Numeric)
      render json: { 'error': 'Column param is either missing or not a number' }, status: 400
      return false
    end

    # All's good. Make sure its the players turn
    if get_next_player != @player.id.to_s
      render json: { 'error': 'Player tried to move when it is not their turn.' }, status: 409
      return false
    end

    if params[:column].negative? || params[:column] >= @game.columns
      render json: { 'error': 'Move attempted outside of game board.' }, status: 409
      return false
    end

    if @game.finished
      render json: { 'error': 'Game has already finished.' }, status: 409
      return false
    end

    true
  end

  def get_next_player
    return @game.current_players.first if @game.last_player_move.nil?
    num_players = @game.current_players.size
    @game.current_players.each.with_index do |player, index|
      if player == @game.last_player_move.to_s
        # Grab the next player in the array.
        # First we need to check if the index has wrapped around though.
        if index == num_players - 1
          # Wrap around. Return the first player in the array.
          return @game.current_players.first
        else
          return @game.current_players[index + 1]
        end
      end
    end
  end

  def check_for_winner(x, y)
    # Theres 4 possible ways for someone to win. They have to get
    # 4 consecutive 'tokens' either in the same row, in the same
    # column or in one of the diagonals
    return true if check_winning_row(x, y)
    return true if check_winning_column(x, y)
    return true if check_winning_left_diag(x, y)
    return true if check_winning_right_diag(x, y)

    return false
  end

  def check_winning_row(start_x, start_y)
    # The algorithm here is we're going to start at the given X and y, move to the left
    # until we either hit the game board edge or we find a token that doesn't
    # match the given player id. We will then go back to the provided x and y and
    # move to the right until we either find a token that doesnt match the player id
    # or we hit the number of consecutive tokens in a row to win.

    game_board = JSON.parse @game.board
    game_board.default = {}
    num_consec = 1 # We know we have at least one, the token at start_x and start_y
    x_index = start_x

    # Check to the left
    while x_index > 0 && compare(x_index, start_y, x_index - 1, start_y, game_board)
      x_index -= 1
      num_consec += 1
      return true if num_consec == 4
    end

    # Reset the x index and check to the right
    x_index = start_x
    while x_index < @game.columns && compare(x_index, start_y, x_index + 1, start_y, game_board)
      x_index += 1
      num_consec += 1
      return true if num_consec == 4
    end

    return false
  end

  def check_winning_column(start_x, start_y)
    # The algorithm here is we're going to start at the given X and y, move down
    # until we either hit the game board edge or we find a token that doesn't
    # match the given player id. We will then go back to the provided x and y and
    # move up until we either find a token that doesnt match the player id
    # or we hit the number of consecutive tokens in a row to win.

    game_board = JSON.parse @game.board
    game_board.default = {}
    num_consec = 1 # We know we have at least one, the token at start_x and start_y
    y_index = start_y

    # Check to the left
    while y_index > 0 && compare(start_x, y_index, start_x, y_index - 1, game_board)
      y_index -= 1
      num_consec += 1
      return true if num_consec == 4
    end

    # Reset the x index and check to the right
    y_index = start_y
    while y_index < @game.rows && compare(start_x, y_index,  start_x, y_index + 1, game_board)
      y_index += 1
      num_consec += 1
      return true if num_consec == 4
    end

    return false
  end

  def check_winning_left_diag(start_x, start_y)
    # The algorithm here is we're going to start at the given X and y, move down
    # until we either hit the game board edge or we find a token that doesn't
    # match the given player id. We will then go back to the provided x and y and
    # move up until we either find a token that doesnt match the player id
    # or we hit the number of consecutive tokens in a row to win.

    game_board = JSON.parse @game.board
    game_board.default = {}
    num_consec = 1 # We know we have at least one, the token at start_x and start_y
    x_index = start_x
    y_index = start_y

    # Check to the left
    while (x_index < @game.columns && y_index > 0) && compare(start_x, y_index, x_index + 1, y_index - 1, game_board)
      x_index += 1
      y_index -= 1
      num_consec += 1
      return true if num_consec == 4
    end

    # Reset the x index and check to the right
    x_index = start_x
    y_index = start_y
    while (x_index > 0 && y_index < @game.rows) && compare(start_x, y_index,  x_index - 1, y_index + 1, game_board)
      x_index -= 1
      y_index += 1
      num_consec += 1
      return true if num_consec == 4
    end

    return false
  end

  def check_winning_right_diag(start_x, start_y)
    # The algorithm here is we're going to start at the given X and y, move down
    # until we either hit the game board edge or we find a token that doesn't
    # match the given player id. We will then go back to the provided x and y and
    # move up until we either find a token that doesnt match the player id
    # or we hit the number of consecutive tokens in a row to win.

    game_board = JSON.parse @game.board
    game_board.default = {}
    num_consec = 1 # We know we have at least one, the token at start_x and start_y
    x_index = start_x
    y_index = start_y

    # Check to the left
    while (x_index > 0 && y_index > 0) && compare(start_x, y_index, start_x - 1, y_index - 1, game_board)
      x_index -= 1
      y_index -= 1
      num_consec += 1
      return true if num_consec == 4
    end

    # Reset the x index and check to the right
    x_index = start_x
    y_index = start_y
    while (x_index < @game.columns && y_index < @game.rows) && compare(start_x, y_index,  start_x + 1, y_index + 1, game_board)
      x_index += 1
      y_index += 1
      num_consec += 1
      return true if num_consec == 4
    end

    return false
  end

  def compare(x1, y1, x2, y2, board)
    return false if board[x2.to_s][y2.to_s].nil?

    return true if board[x1.to_s][y1.to_s] == board[x2.to_s][y2.to_s]

    return false
  end
end
