require_relative 'adt'
require 'renet'

module SimultSim

  class EnetServerEvent < ADT
    PeerConnected    = data :source_id, :ip
    PeerDisconnected = data :source_id
    PeerPacket       = data :source_id, :data
  end

  class ReNetServer
    attr_reader :clients
    def initialize(server)
      @server = server
      @clients = {}
      @callback = lambda { }
    end

    def self.host(host_port)
      server = ENet::Server.new(host_port, 32, 0, 0, 0)
      renet_server = ReNetServer.new(server)
      server.on_connection(renet_server.method(:handle_peer_connect))
      server.on_disconnection(renet_server.method(:handle_peer_disconnect))
      server.on_packet_receive(renet_server.method(:handle_incoming_peer_packet))
      renet_server
    end

    def handle_peer_connect(source_id, ip)
      @clients[source_id] = ip
      @callback.call(EnetServerEvent::PeerConnected.new(source_id, ip))
    end

    def handle_peer_disconnect(source_id)
      @clients.delete source_id
      @callback.call(EnetServerEvent::PeerDisconnected.new(source_id))
    end

    def handle_incoming_peer_packet(source_id, data, channel)
      @callback.call(EnetServerEvent::PeerPacket.new(source_id, data))
    end

    def update(&blk)
      @callback = blk  #a hack to mold the interface into the shape I want
      @server.update(1)
    end

    def send_packet(source_id, data) @server.send_packet(source_id, data, true, 0) end

    def broadcast(data)
      @server.broadcast_packet(data, true, 0)
    end

    def disconnect_client(source_id) @server.disconnect_client(source_id) end

    def shutdown()
      @clients.keys.each do |source_id|
        disconnect_client(source_id)
      end
      @server = nil
    end
  end
end
