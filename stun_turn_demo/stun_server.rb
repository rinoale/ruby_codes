#!/usr/bin/env ruby
# Standalone STUN + rendezvous server.
#
#   ruby stun_server.rb [port]      # default port 3478
#
# - Answers Binding Requests with the client's reflexive address
#   (XOR-MAPPED-ADDRESS): "this is what you look like from outside".
# - Mediates peers: clients REGISTER into a room, and when two peers are in
#   the same room the server sends each one a PEER-INFO Indication carrying
#   the other's IP:port. After that the peers talk directly — no traffic
#   flows through this server.
require_relative 'rendezvous'

$stdout.sync = true

PORT = (ARGV[0] || 3478).to_i
sock = UDPSocket.new
sock.bind('0.0.0.0', PORT)
$stdout.write("[stun-server] listening on 0.0.0.0:#{PORT}/udp (STUN binding + room rendezvous)\n")

loop do
  data, (_, sport, _, sip) = sock.recvfrom(2048)
  next unless Stun.stun_packet?(data)
  PacketLog.log('stun-server', :recv, "#{sip}:#{sport}", data)
  msg = Stun.parse(data)
  unless Rendezvous.handle('stun-server', sock, msg, sip, sport)
    $stdout.write(format("[stun-server] unhandled message type 0x%04x\n", msg[:type]))
  end
rescue Interrupt
  break
rescue => e
  warn "[stun-server] error: #{e.class}: #{e.message}"
end
