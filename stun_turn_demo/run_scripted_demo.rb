#!/usr/bin/env ruby
# The original fully-automated walkthrough: STUN server, TURN server,
# signaling server, scripted peer B, scripted peer A — all as separate
# processes on localhost, sharing this terminal.
ruby = RbConfig.ruby
here = __dir__

servers = %w[stun_server.rb turn_server.rb signaling_server.rb].map do |s|
  Process.spawn(ruby, File.join(here, s))
end
sleep 0.5

peer_b = Process.spawn(ruby, File.join(here, 'scripted_peer.rb'), 'B')
sleep 0.3
peer_a = Process.spawn(ruby, File.join(here, 'scripted_peer.rb'), 'A')

Process.wait(peer_a)
Process.wait(peer_b)
sleep 0.5

servers.each { |pid| Process.kill('TERM', pid) rescue nil }
servers.each { |pid| Process.wait(pid) rescue nil }
puts "\n[demo] finished"
