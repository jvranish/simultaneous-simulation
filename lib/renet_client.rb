require_relative 'adt'
require 'renet'

module SimultSim
  class EnetClientEvent < ADT
    Disconnected = data
    Packet       = data :data
  end

  class ReNetClient
    class ReNetClientException < Exception; end

    def initialize(socket)
      @socket = socket
      @callback = lambda { }
    end

    def self.connect(host, port, timeout = 3000)
      socket = ENet::Connection.new(host, port, 2, 0, 0)
      renet_socket = ReNetClient.new(socket)
      socket.on_disconnection(renet_socket.method(:handle_disconnect))
      socket.on_packet_receive(renet_socket.method(:handle_incoming_packet))
      raise ReNetClientException.new("error connecting to #{host}:#{port}") if socket.connect(timeout).nil?
      renet_socket
    end

    def update(&blk)
      @callback = blk
      @socket.update(1)
    end

    def handle_disconnect()
      @callback.call(EnetClientEvent::Disconnected.new)
    end

    def handle_incoming_packet(data, channel)
      @callback.call(EnetClientEvent::Packet.new(data))
    end

    def update(&blk)
      @callback = blk  #a hack to mold the interface into the shape I want
      @socket.update(1)
    end

    def send_packet(data) @socket.send_packet(data, true, 0) end

    def disconnect() @socket.disconnect(1000) end
  end
end
