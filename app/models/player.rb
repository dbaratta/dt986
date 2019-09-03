class Player
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :game

  field :name, type: String

end
