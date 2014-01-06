require 'gosu'
require 'vector2d'
require 'sim_client'
require 'zlib'

include SimultSim
include Gosu


LEFT  = Vector2d.new(-1.0,  0.0)
RIGHT = Vector2d.new( 1.0,  0.0)
UP    = Vector2d.new( 0.0, -1.0)
DOWN  = Vector2d.new( 0.0,  1.0)
ZERO_VECTOR = Vector2d.new(0.0, 0.0)

class Bounds < Struct.new(:width, :height)
end

class Player < Struct.new(:pos, :vel)
  def step(dt)
    self.pos += (vel * dt)
  end
end

class World < Struct.new(:prgn, :sub_step, :bounds, :players)
  def initialize(bounds)
    super(Random.new, 0, bounds, {})
  end
  def add_player(id)
    pos = Vector2d.new(prgn.rand(0..bounds.width - 1),
                       prgn.rand(0..bounds.height - 1))
    players[id] = Player.new(pos, ZERO_VECTOR)
  end
  def remove_player(id)
    players.delete(id)
  end
  def set_player_vel(id, vel)
    players[id].vel = vel
  end
  def step
    if self.sub_step < 6
      self.sub_step += 1
      players.values.each do |p|
        p.step(1.0/60.0)
      end
    end
  end
  def turn
    while self.sub_step < 6
      step
    end
    self.sub_step = 0
  end
end


DIRECTIONS = { Gosu::KbLeft  => LEFT,
               Gosu::KbRight => RIGHT,
               Gosu::KbUp    => UP,
               Gosu::KbDown  => DOWN }

class Game < Gosu::Window
  attr_reader :images
  def initialize()
    super(480, 480, false)
    @last_time = Gosu::milliseconds

    self.caption = "test framework for simultaneous simulation" 
    @images = { evoker: Image.new(self, "./gfx/evoker.base.172.png", false),
                 floor: Image.new(self, "./gfx/flagstone.base.111.png", false) }
    @our_id = nil
    @world = World.new(Bounds.new(15, 15))

    @connection = Client.connect("localhost", 8000)
    @current_time = Gosu::milliseconds
    @last_time = 0
    @last_player_vel = ZERO_VECTOR
  end

  def move
  end

  def needs_cursor?
    return true
  end
  # if events are applied at turn boundary (which they must if we have intermediate world updates)
  #   and world steps are recorded by the client and then forwarded along with the world
  #   we should be able to pull up a gamestate at any point in the even stream
  def update
    @connection.update do |client_events|
      case client_events
      when GameEvent::TurnComplete.match do |turn_number, events, checksum_closure|
        @world.turn
        events.each do |event|
          case event
            when SimulationEvent::Event
              #TODO make a better serialize/deserialize setup
              @world.set_player_vel(event.player_id, Marshal.load(event.data))
            when SimulationEvent::PlayerJoined.match do |player_id|
              puts "Player joined: #{player_id}"
              @world.add_player(player_id)
              end
            when SimulationEvent::PlayerLeft.match do |player_id|
              puts "Player left: #{player_id}"
              @world.remove_player(player_id)
              end
          end
        end
        checksum = Zlib::crc32(Marshal.dump(@world))
        checksum_closure.call(checksum)
        end
      when GameEvent::StartGame.match do |our_id, turn_period, current_turn, gamestate|
        @our_id = our_id
        @world = Marshal.load(gamestate)
        end
      when GameEvent::GamestateRequest.match do |gamestate_closure|
        gamestate_closure.call(Marshal.dump(@world))
        end
      when GameEvent::Disconnected
        puts "Disconnected"
        quit
      end
    end

    @current_time = Gosu::milliseconds
    if (@current_time - @last_time) >= (1000.0/60.0).to_i && !@our_id.nil?
      @last_time = @current_time
      @world.step
    end

    commanded_directions = DIRECTIONS.select{ |key, value| self.button_down? key }.values
    # todo ignore sending events with the same velocity
    player_vel = commanded_directions.inject(ZERO_VECTOR) { |sum, x| sum + x }
    if player_vel != @last_player_vel
      @connection.send_event(Marshal.dump(player_vel * 5.0))
    end
    @last_player_vel = player_vel
  end
  
  def draw
    @world.bounds.width.times do |x|
      @world.bounds.height.times do |y|
        images[:floor].draw(x * 32, y * 32, 0)
      end
    end
    @world.players.values.each do |p|
      images[:evoker].draw((p.pos.x * 32).round, (p.pos.y * 32).round, 1)
    end
  end

  def quit
    close
  end

  def button_down(id)
    if id == Gosu::KbSpace then
      
    end
    if id == Gosu::KbEscape then
      @connection.disconnect
      quit
    end
  end
end

g = Game.new()
g.show
