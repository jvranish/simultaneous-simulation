#!/usr/bin/env ruby
require 'sim_server'

include SimultSim

class ServerThread
  def initialize(server)
    @server = server
    @thread = nil
    @done = false
  end

  def shutdown
    @done = true
    @thread.join
  end

  def run(&on_event)
    @thread = Thread.new do
      while not @done
        @server.update do |e|
          on_event.call(e)
        end
      end
      @server.shutdown
    end
    self
  end

  def self.create(host_port, on_event, &blk)
    server_thread = ServerThread.new(Server.host(host_port))
    begin
      server_thread.run(&on_event)
      blk.call(server_thread)
    ensure
      server_thread.shutdown
    end
  end
end

on_event = lambda do |e|
  case e
  when EnetServerEvent::PeerConnected.match do |source_id, ip|
    puts "Peer connected, ip: #{ip}, id: #{source_id}"
    end
  when EnetServerEvent::PeerDisconnected.match do |source_id|
    puts "Peer disconnected, id: #{source_id}"
    end
  end
end

ServerThread.create(8000, on_event) do |s|
  puts "press any enter to terminate server"
  STDIN.gets
end