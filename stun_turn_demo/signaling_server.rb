#!/usr/bin/env ruby
# Tiny "signaling" channel (stands in for what WebRTC apps do over
# websockets etc.). STUN/TURN only tell a peer its own addresses —
# the peers still need some out-of-band channel to exchange candidates.
# This just relays JSON lines between the two connected peers.
require 'socket'

$stdout.sync = true

server = TCPServer.new('127.0.0.1', 5001)
$stdout.write("[signaling] listening on 127.0.0.1:5001/tcp (relays candidate info between peers)\n")

a = server.accept
b = server.accept
$stdout.write("[signaling] both peers connected\n")

[[a, b], [b, a]].map do |from, to|
  Thread.new do
    while (line = from.gets)
      $stdout.write("[signaling] relaying: #{line}")
      to.puts(line)
    end
  end
end.each(&:join)
