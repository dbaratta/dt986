json.moves do
  json.array! @moves, partial: 'move_detail', as: :move
end