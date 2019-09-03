class Game
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :players
  embeds_many :moves

  field :finished, type: Boolean
  field :columns, type: Numeric
  field :rows, type: Numeric
  field :winner, type: String
  field :last_player_move, type: BSON::ObjectId
  field :board, type: String
  field :current_players, type: Array

  scope :in_progress, -> { where(finished: false) }
end
