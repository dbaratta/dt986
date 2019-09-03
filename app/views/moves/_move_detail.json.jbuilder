json.type move.move_type
json.player Player.find(move.player_id).name
if move.move_type == "MOVE"
  json.column move.column
end