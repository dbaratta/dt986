json.players do
  json.array! @initial_players
end

json.state @game.finished ? "DONE" : "IN_PROGRESS"
if @game.finished
  if @game.winner
    json.winner Player.find(@game.winner).name
  else
    json.winner nil
  end
end
