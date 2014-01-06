require 'adt'

module SimultSim

  class ClientMsg < Packable_ADT 
    Event             = data :data                       # send event to all connected clients
    Gamestate         = data :for_player_id, :proto_turn, :data          # server forwards to player
    TurnFinished      = data :turn_number, :checksum
  end

  class ServerMsg < Packable_ADT
    IdAssigned               = data :our_id
    PlayerJoined             = data :player_id
    Event                    = data :source_player_id, :data
    PlayerLeft               = data :player_id
    TurnComplete             = data :turn_number
    StartGame                = data :your_id, :turn_period, :current_turn, :proto_turn, :gamestate
    GamestateRequest         = data :for_player_id
  end
end
