require "zlib"

module SimultSim

  class WorldProxyEvent < Struct.new(:m, :args)
  end

  class WorldProxy
    def initialize(simulation)
      @simulation = simulation
    end
    def method_missing(m, *args, &block)
      @simulation.send_event(
          WorldProxyEvent.new(m, args))
    end
  end

  class DefaultEventSerializer
    def self.dump(event)
      Marshal.dump(event)
    end
    def self.load(serialized_event)
      Marshal.load(serialized_event)
    end
  end

  class SimState < Struct.new(:time_per_turn,
                              :steps_per_turn,
                              :turn,
                              :sub_step,
                              :world)
    def turn
      step_until(steps_per_turn)
      self.sub_step = 0
    end

    def step_time
      time_per_turn.to_f / steps_per_turn.to_f
    end 

    def step_until(n)
      should_be_at_step = [n, steps_per_turn].min
      while self.sub_step < should_be_at_step
        self.sub_step += 1
        world.step(step_time)
      end
    end

    def dump
      Marshal.dump([
        time_per_turn,
        steps_per_turn,
        turn,
        sub_step,
        world.dump,
      ])
    end

    def self.load(world_class, serialized_simstate)
      time_per_turn,
      steps_per_turn,
      turn,
      sub_step,
      serialized_world = Marshal.load(serialized_simstate)


      SimState.new(time_per_turn,
                   steps_per_turn,
                   turn,
                   sub_step,
                   world_class.load(serialized_world))
      end
  end

  class Simulation
    attr_reader :world_proxy
    attr_reader :our_id
    attr_reader :event_serializer

    def initialize(world_class,
                   connection,
                   default_time_per_turn,
                   default_steps_per_turn,
                   event_serializer = DefaultEventSerializer)
      @world_class = world_class
      @world_proxy = WorldProxy.new(self)
      @connection = connection
      @sim_state = nil
      @our_id = nil
      @last_turn_time = 0.0
      @event_serializer = event_serializer
      @default_time_per_turn = default_time_per_turn
      @default_steps_per_turn = default_steps_per_turn
    end

    def world_state
      @sim_state && @sim_state.world
    end

    def send_event(event)
      @connection.send_event(@event_serializer::dump(event))
    end

    def default_sim_state
      @sim_state = SimState.new(@default_time_per_turn,
                                @default_steps_per_turn,
                                0,
                                0,
                                @world_class.default_world)
    end

    def turn(t)
      @sim_state.turn
      @last_turn_time = t
    end

    def quit
      @connection.disconnect
      @sim_state = nil
    end

    def update(t)
      if not @sim_state.nil?
        this_turn_time = t.to_f - @last_turn_time
        should_be_at_step = [(this_turn_time / @sim_state.step_time).round, @sim_state.steps_per_turn].min
        @sim_state.step_until(should_be_at_step)
      end

      @connection.update do |client_events|
        case client_events
        when GameEvent::TurnComplete.match do |turn_number, events, checksum_closure|
          turn(t)
          events.each do |event|
            case event
              when SimulationEvent::Event
                incoming_event = @event_serializer::load(event.data)
                case incoming_event
                when WorldProxyEvent
                  @sim_state.world.send(incoming_event.m,
                                        event.player_id,
                                        *incoming_event.args)
                else
                  @sim_state.world.incoming_event(event.player_id, incoming_event)
                end
              when SimulationEvent::PlayerJoined.match do |player_id|
                @sim_state.world.player_joined(player_id)
                end
              when SimulationEvent::PlayerLeft.match do |player_id|
                @sim_state.world.player_left(player_id)
                end
            end
          end
          # TODO perhaps I should checksum the simstate too?
          checksum = @sim_state.world.checksum
          checksum_closure.call(checksum)
          end
        when GameEvent::StartGame.match do |our_id, turn_period, current_turn, gamestate|
          @our_id = our_id 
          @sim_state = SimState.load(@world_class, gamestate)
          end
        when GameEvent::GamestateRequest.match do |gamestate_closure|
          sim_state = @sim_state.nil? ? default_sim_state : @sim_state
          # @sim_state = sim_state
          gamestate_closure.call(sim_state.dump)
          end
        when GameEvent::Disconnected
          puts "Disconnected"
          #Todo need to notify users of the simulation that we were disconnected
          @sim_state = nil
        end
      end
    end
  end

  module SimInterface
    # apparently this is the "standard" idiom for supporting class methods with
    # mixins, though I don't like it much :/
    def self.included(base)
        base.send(:include, InstanceMethods)
        base.extend(ClassMethods)
      end

    module InstanceMethods
      def player_joined(id)
        raise "needs to be implemented"
      end

      def player_left(id)
        raise "needs to be implemented"
      end

      def incoming_event(source_id, event)
        raise "does not needs to be implemented, unless you want custom events"
      end

      def checksum
        Zlib::crc32(self.dump)
      end

      def dump
        Zlib::Deflate.deflate(Marshal.dump(self))
      end

      def step(dt)
        raise "needs to be implemented"
      end
    end

    module ClassMethods
      def load(serialized_world)
        Marshal.load(Zlib::Inflate.inflate(serialized_world))
      end

      def default_world
        self.new
      end
    end
  end
end


