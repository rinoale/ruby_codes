#!/usr/bin/env ruby
# A peer that connects to another peer, first directly (addresses learned
# via STUN), then through a TURN relay.
#
#   ruby peer.rb A    # the "offerer": drives the demo, owns the TURN allocation
#   ruby peer.rb B    # the "answerer"
require_relative 'stun_message'
require 'json'

$stdout.sync = true

ROLE = ARGV[0]
abort 'usage: ruby peer.rb A|B' unless %w[A B].include?(ROLE)
ME = "peer-#{ROLE}"

STUN = ['127.0.0.1', 3478].freeze
TURN = ['127.0.0.1', 3479].freeze
TURN_ADDR = "#{TURN[0]}:#{TURN[1]}"

sig = TCPSocket.new('127.0.0.1', 5001)

# One UDP socket for everything (STUN, P2P, TURN) — matching ports is what
# makes the reflexive address reusable for hole punching in real NATs.
sock = UDPSocket.new
sock.bind('127.0.0.1', 0)

def sig_send(sig, hash) = sig.puts(hash.to_json)
def sig_recv(sig) = JSON.parse(sig.gets)

# ---------------------------------------------------------------- STEP 1
# Ask the STUN server "what do I look like from the outside?"
# B waits for A's candidate first, purely to keep the demo output ordered.
peer_cand = sig_recv(sig) if ROLE == 'B'

Stun.banner("STEP 1: #{ME} asks the STUN server for its reflexive address")

req = Stun.build(Stun::BINDING_REQUEST, Stun.new_txid,
                 [[Stun::ATTR_SOFTWARE, "ruby-demo-#{ME}"]])
PacketLog.log(ME, :send, "#{STUN[0]}:#{STUN[1]}", req)
sock.send(req, 0, *STUN)

data, = sock.recvfrom(1500)
PacketLog.log(ME, :recv, "#{STUN[0]}:#{STUN[1]}", data)
my_ip, my_port = Stun.unxor_address(
  Stun.attr(Stun.parse(data), Stun::ATTR_XOR_MAPPED_ADDRESS))
$stdout.write("[#{ME}] STUN says my reflexive address is #{my_ip}:#{my_port}\n")

# ---------------------------------------------------------------- STEP 2
# Exchange candidates over the signaling channel (out-of-band; STUN/TURN
# never do this part for you).
if ROLE == 'A'
  Stun.banner('STEP 2: peers exchange candidates over the signaling channel (TCP, not STUN)')
end
sig_send(sig, role: ROLE, kind: 'candidate', ip: my_ip, port: my_port)
peer_cand ||= sig_recv(sig)
peer_ip, peer_port = peer_cand['ip'], peer_cand['port']
$stdout.write("[#{ME}] learned peer candidate #{peer_ip}:#{peer_port} via signaling\n")

# ---------------------------------------------------------------- STEP 3
# Direct P2P: send straight to the other peer's reflexive address.
# (Behind real NATs both sides send simultaneously — "hole punching".)
if ROLE == 'A'
  Stun.banner('STEP 3: direct P2P — peers talk to each other, no server in the path')
  msg = 'PING direct P2P from A'
  PacketLog.log(ME, :send, "#{peer_ip}:#{peer_port}", msg, note: 'direct to peer')
  sock.send(msg, 0, peer_ip, peer_port)
  data, (_, pport, _, pip) = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, "#{pip}:#{pport}", data, note: 'direct from peer')
else
  data, (_, pport, _, pip) = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, "#{pip}:#{pport}", data, note: 'direct from peer')
  reply = 'PONG direct P2P from B'
  PacketLog.log(ME, :send, "#{pip}:#{pport}", reply, note: 'direct to peer')
  sock.send(reply, 0, pip, pport)
end

# ---------------------------------------------------------------- STEP 4
# TURN: when direct P2P is impossible (symmetric NAT etc.), peer A rents a
# relay address on the TURN server and all traffic flows through it.
if ROLE == 'A'
  Stun.banner('STEP 4: TURN relay — peer-A allocates, then traffic flows via the server')

  # 4a. Allocate a relay address
  req = Stun.build(Stun::ALLOCATE_REQUEST, Stun.new_txid, [
    [Stun::ATTR_REQUESTED_TRANSPORT, [17, 0, 0, 0].pack('C4')], # 17 = UDP
    [Stun::ATTR_LIFETIME, [600].pack('N')],
  ])
  PacketLog.log(ME, :send, TURN_ADDR, req)
  sock.send(req, 0, *TURN)
  data, = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, TURN_ADDR, data)
  relay_ip, relay_port = Stun.unxor_address(
    Stun.attr(Stun.parse(data), Stun::ATTR_XOR_RELAYED_ADDRESS))
  $stdout.write("[#{ME}] TURN gave me relayed address #{relay_ip}:#{relay_port}\n\n")

  # 4b. Permit peer B to send to my relay
  req = Stun.build(Stun::CREATE_PERMISSION_REQ, Stun.new_txid, [
    [Stun::ATTR_XOR_PEER_ADDRESS, Stun.xor_address(peer_ip, peer_port)],
  ])
  PacketLog.log(ME, :send, TURN_ADDR, req)
  sock.send(req, 0, *TURN)
  data, = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, TURN_ADDR, data)

  # 4c. Tell B where my relay lives (signaling again)
  sig_send(sig, role: ROLE, kind: 'relay', ip: relay_ip, port: relay_port)

  # 4d. B's message arrives wrapped in a Data Indication
  data, = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, TURN_ADDR, data, note: "B's data, wrapped by TURN")
  msg = Stun.parse(data)
  b_ip, b_port = Stun.unxor_address(Stun.attr(msg, Stun::ATTR_XOR_PEER_ADDRESS))
  $stdout.write("[#{ME}] received via relay from #{b_ip}:#{b_port}: " \
                "#{Stun.attr(msg, Stun::ATTR_DATA).inspect}\n\n")

  # 4e. Reply through the relay with a Send Indication
  ind = Stun.build(Stun::SEND_INDICATION, Stun.new_txid, [
    [Stun::ATTR_XOR_PEER_ADDRESS, Stun.xor_address(b_ip, b_port)],
    [Stun::ATTR_DATA, 'REPLY via TURN relay from A'],
  ])
  PacketLog.log(ME, :send, TURN_ADDR, ind, note: 'asking TURN to relay my reply to B')
  sock.send(ind, 0, *TURN)
else
  relay = sig_recv(sig)
  relay_addr = "#{relay['ip']}:#{relay['port']}"
  $stdout.write("[#{ME}] learned A's relay address #{relay_addr} via signaling\n\n")

  # B just sends plain UDP to the relayed address — from B's point of view
  # the relay looks exactly like peer A would.
  msg = 'HELLO via TURN relay from B'
  PacketLog.log(ME, :send, relay_addr, msg, note: "A's relayed address on the TURN server")
  sock.send(msg, 0, relay['ip'], relay['port'])

  data, (_, pport, _, pip) = sock.recvfrom(1500)
  PacketLog.log(ME, :recv, "#{pip}:#{pport}", data, note: "A's reply, forwarded by the relay")
end

sleep 0.3 # let in-flight log output flush before the runner tears down
$stdout.write("[#{ME}] done\n")
