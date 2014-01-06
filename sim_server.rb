require 'msgs'
require 'renet_server'

module SimultSim

  class Turn
    attr_reader :period
    attr_reader :current

    def initialize(turn_period)
      @period = turn_period.to_f
      @last_turn_time = 0.0
      @current = 0
    end
    def turn_ended?
      now = Time.now.to_f
      if @last_turn_time + @period < now
        yield @current
        @current += 1
        @last_turn_time = now
      end
    end
  end

  # class PktDest < ADT
  #   Everyone = data
  #   Just     = data :player_id
  # end



  class Server
    def initialize(server)
      @server = server
      @send_next_turn = []
      @turn = nil
    end

    def self.host(host_port)
      Server.new(ReNetServer.host(host_port))
    end

    def update
      if @turn
        @turn.turn_ended? do |current_turn|
          send_msg(:everyone, ServerMsg::TurnComplete.new(current_turn))
        end
      end
      @server.update do |event|
        case event
        when EnetServerEvent::PeerConnected
          send_msg(event.source_id, ServerMsg::IdAssigned.new(event.source_id))
          if @server.clients.count == 1
            #kinda hacky. If this is the first player, tell them to send a
            #  gamestate to themselves (starts the game)
            @turn = Turn.new(0.1)
            send_msg(event.source_id, ServerMsg::GamestateRequest.new(event.source_id))
          else
            other_players = @server.clients.keys.dup
            other_players.delete(event.source_id)
            send_msg(other_players.first, ServerMsg::GamestateRequest.new(event.source_id))
          end
          
          send_msg(:everyone, ServerMsg::PlayerJoined.new(event.source_id))

        when EnetServerEvent::PeerDisconnected
          send_msg(:everyone, ServerMsg::PlayerLeft.new(event.source_id))

        when EnetServerEvent::PeerPacket
          msg = ClientMsg::unpack(event.data)
          case msg
            when ClientMsg::Event
              send_msg(:everyone, ServerMsg::Event.new(event.source_id, msg.data))

            when ClientMsg::Gamestate
              send_msg(msg.for_player_id, ServerMsg::StartGame.new(msg.for_player_id, @turn.period, @turn.current, msg.proto_turn, msg.data))

            when ClientMsg::TurnFinished
              #TODO do something toward checksum verification here
          end
        end
        yield event
      end
    end

    def send_next_turn(dest_id, msg) @send_next_turn << [dest_id, msg] end

    def send_msg(dest_id, msg)
      # TODO switch this out for an ADT? 
      # I'd like it better, but object construction might be expensive :(
      if dest_id == :everyone
        @server.broadcast(msg.pack)
      else
        @server.send_packet(dest_id, msg.pack)
      end
    end
    def disconnect_client(source_id) @server.disconnect_client(source_id) end
    #maybe hide this and only use block for host/shutdown
    def shutdown()
      @server.shutdown
    end
  end
end

