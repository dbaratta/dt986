class Move
  include Mongoid::Document
  include Mongoid::Timestamps

  field :player_id, type: String
  field :move_type, type: String
  field :column, type: Numeric

  embedded_in :game

  def to_builder
    Jbuilder.new do |move|
      json.type move.move_type
      json.player Player.find(move.player_id).name
      if move.move_type == "MOVE"
        json.column move.column
      end
    end
  end
end
