#!/usr/bin/env ruby
require 'gosu'
require 'vector2d'
require 'sim_client'
require 'zlib'
require 'simulation'

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
  include SimInterface

  def initialize(bounds)
    super(Random.new, 0, bounds, {})
  end
  def self.default_world
    World.new(Bounds.new(15, 15))
  end
  def player_joined(id)
    puts "Player joined: #{id}"
    pos = Vector2d.new(prgn.rand(0..bounds.width - 1),
                       prgn.rand(0..bounds.height - 1))
    players[id] = Player.new(pos, ZERO_VECTOR)
  end
  def player_left(id)
    puts "Player left: #{id}"
    players.delete(id)
  end
  def set_player_vel(id, vel)
    players[id].vel = vel
  end
  def step(dt)
    players.values.each { |p| p.step(dt) }
  end
end

def sum(a, zero = 0) a.inject(zero, :+) end 

class OnChange
  def initialize(v) @v = v end
  def on_change(v)
    if @v != v
      @v = v
      yield v
    end
  end
end

DIRECTIONS = { Gosu::KbLeft  => LEFT,
               Gosu::KbRight => RIGHT,
               Gosu::KbUp    => UP,
               Gosu::KbDown  => DOWN }

class GameWindow < Gosu::Window
  attr_reader :images
  def initialize(simulation)
    super(480, 480, false)
    @simulation = simulation

    self.caption = "test framework for simultaneous simulation" 

    @images = { evoker: Image.new(self, "./gfx/evoker.base.172.png", false),
                 floor: Image.new(self, "./gfx/flagstone.base.111.png", true) }

    @player_vel = OnChange.new ZERO_VECTOR
  end

  def needs_cursor?() true end

  def update
    @simulation.update(Gosu::milliseconds/1000.0)

    commanded_directions = DIRECTIONS.select{ |key, value| self.button_down? key }.values
    #ignore sending events with the same velocity
    @player_vel.on_change(sum(commanded_directions, ZERO_VECTOR)) do |player_vel|
      @simulation.world_proxy.set_player_vel(player_vel * 5.0)
    end
  end
  
  def draw
    if @simulation.world_state
      @simulation.world_state.bounds.width.times do |x|
        @simulation.world_state.bounds.height.times do |y|
          images[:floor].draw(x * 32, y * 32, 0)
        end
      end
      @simulation.world_state.players.values.each do |p|
        images[:evoker].draw((p.pos.x * 32).round, (p.pos.y * 32).round, 1)
      end
    end
  end

  def button_down(id)
    # if id == Gosu::KbSpace then
      
    # end
    if id == Gosu::KbEscape then
      @simulation.quit
      close
    end
  end
end

host = ARGV.first || "localhost"
connection = Client.connect(host, 8000)
simulation = Simulation.new(World, connection, 0.1, 6)
game_window = GameWindow.new(simulation)
game_window.show()

