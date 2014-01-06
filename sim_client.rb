require 'msgs'
require 'renet_client'

module SimultSim

  class SimulationEvent < ADT
    # send at beginning of next turn
    PlayerJoined             = data :player_id
    # send as soon as it happens
    PlayerLeft               = data :player_id
    Event                    = data :player_id, :data
  end

  class GameEvent < ADT
    # sent at periodic tick,
    TurnComplete             = data :turn_number, :events, :checksum_closure
    # send immediately to client
    StartGame                = data :our_id,
                                    :turn_period,
                                    :current_turn,
                                    :gamestate
    GamestateRequest         = data :gamestate_closure
    Disconnected             = data
  end

  class Client
    def initialize(socket)
      @socket = socket
      @client_id = nil
      # TODO too much state :(
      #  needs a couple more de-coupling passes
      @game_events_buffer = []
      @simulation_events_buffer = []
      @game_started = false
    end

    def self.connect(host, port, timeout = 3000)
      Client.new(ReNetClient.connect(host, port, timeout))
    end

    def update
      if @socket
        @socket.update do |event|
          case event
          when EnetClientEvent::Disconnected
            @socket = nil
            @game_events_buffer << GameEvent::Disconnected.new

          when EnetClientEvent::Packet
            # buffer packets until we get a start game?

            msg = ServerMsg.unpack(event.data)
            case msg
              when ServerMsg::IdAssigned
                client_id = msg.our_id

              # these next 3 events only apply to the simulation
              # and will only be released to the game when
              # then turn is finished
                when ServerMsg::Event
                  @simulation_events_buffer <<
                    SimulationEvent::Event.new(msg.source_player_id, msg.data)

                when ServerMsg::PlayerJoined
                  @simulation_events_buffer <<
                    SimulationEvent::PlayerJoined.new(msg.player_id)

                when ServerMsg::PlayerLeft
                  @simulation_events_buffer <<
                    SimulationEvent::PlayerLeft.new(msg.player_id)
              
              #
              when ServerMsg::TurnComplete
                # pull out our buffered simulation events
                # and apply them to this turn (and clear the buffer)
                turn_events = @simulation_events_buffer.pop(
                    @simulation_events_buffer.length)

                f = lambda do |checksum|
                  send_msg ClientMsg::TurnFinished.new(msg.turn_number,
                                                       checksum)
                end
                @game_events_buffer <<
                  GameEvent::TurnComplete.new(msg.turn_number, turn_events, f)
              
              when ServerMsg::StartGame  
                # need to emit this as the first game event
                # simulation events queued into a proto-turn

                @game_started = true
                @simulation_events_buffer.concat Marshal.load(msg.proto_turn)
                yield GameEvent::StartGame.new(msg.your_id,
                                               msg.turn_period,
                                               msg.current_turn,
                                               msg.gamestate)
              when ServerMsg::GamestateRequest
                # take all of the events that we have
                #  buffered for the next turn
                proto_turn = Marshal.dump(@simulation_events_buffer)
                f = lambda do |gamestate|
                  send_msg ClientMsg::Gamestate.new(msg.for_player_id,
                                                    proto_turn,
                                                    gamestate)
                end
                #TODO fix this, this is hacky, game start likely needs to be
                #   more explicit
                if @game_started
                  @game_events_buffer << GameEvent::GamestateRequest.new(f)
                else
                  yield GameEvent::GamestateRequest.new(f)
                end
            end
          end
        end

        if @game_started
          while event = @game_events_buffer.shift
            yield event
          end
        end
        true
      else
        false
      end
    end

    def send_event(data)
      send_msg ClientMsg::Event.new(data)
    end

    #make this private?
    def send_msg(msg)
      @socket.send_packet(msg.pack) if @socket
    end

    #TODO, so I really want this = nil here?
    def disconnect() @socket.disconnect() if @socket; @socket = nil end
  end



  # how do we handle x many steps per turn? 
  #   we know the period


  # if we are host, start host, connect, send gamestate
end

