#!/usr/bin/env ruby
# Standalone TURN server (RFC 5766, simplified: no auth/MESSAGE-INTEGRITY).
# Also speaks STUN Binding and the rendezvous extension, like real-world
# servers that serve both roles — so TURN-mode peers only need this one
# server process.
#
#   ruby turn_server.rb [advertised_ip] [port]   # defaults: 127.0.0.1 3479
#   VERBOSE=1 ruby turn_server.rb                # hexdump bulk data too
#
# advertised_ip is the address handed out in XOR-RELAYED-ADDRESS — set it to
# this machine's LAN/public IP when peers connect from other hosts.
#
# Supported TURN messages:
#   Allocate          -> opens a fresh relay UDP socket for the client,
#                        returns its address as XOR-RELAYED-ADDRESS
#   CreatePermission  -> whitelists a peer IP for the allocation
#   Send Indication   -> client -> TURN: unwrap DATA, forward raw to peer
#   (relay socket rx) -> peer -> TURN: wrap in Data Indication, forward to
#                        the allocation's client
require_relative 'rendezvous'

$stdout.sync = true

ADVERTISED_IP = ARGV[0] || '127.0.0.1'
PORT = (ARGV[1] || 3479).to_i
VERBOSE = ENV['VERBOSE'] == '1'
BULK = 512 # payloads bigger than this are counted, not hexdumped

control = UDPSocket.new
control.bind('0.0.0.0', PORT)
$stdout.write("[turn-server] listening on 0.0.0.0:#{PORT}/udp " \
              "(relay addresses advertised as #{ADVERTISED_IP})\n")

allocations = {} # "client_ip:client_port" => { relay:, permissions:, agg: }

# File chunks flying through the relay would flood the terminal — log small
# (control/chat) packets in full, count bulk data and print a summary line.
def log_bulk(role, dir, remote, data, agg, note: nil)
  if VERBOSE || data.bytesize <= BULK
    PacketLog.log(role, dir, remote, data, note: note)
  else
    agg[:n] += 1
    agg[:bytes] += data.bytesize
    if agg[:n] == 1 || (agg[:n] % 1000).zero?
      PacketLog.brief(role, dir, remote,
                      "bulk data #{data.bytesize} bytes (#{agg[:n]} pkts / #{agg[:bytes]} bytes relayed so far)#{note ? "  (#{note})" : ''}")
    end
  end
end

loop do
  data, (_, sport, _, sip) = control.recvfrom(65_536)
  client_key = "#{sip}:#{sport}"
  unless Stun.stun_packet?(data)
    PacketLog.log('turn-server', :recv, client_key, data, note: 'ignored: not STUN')
    next
  end
  msg = Stun.parse(data)

  case msg[:type]
  when Stun::ALLOCATE_REQUEST
    PacketLog.log('turn-server', :recv, client_key, data)
    relay = UDPSocket.new
    relay.bind('0.0.0.0', 0) # ephemeral port; this becomes the relayed address
    relay_port = relay.addr[1]
    alloc = { relay: relay, permissions: [], agg: { n: 0, bytes: 0 } }
    allocations[client_key] = alloc

    # Anything a peer sends to the relayed address gets wrapped in a
    # Data Indication and forwarded to the client that owns the allocation.
    Thread.new do
      loop do
        d, (_, pport, _, pip) = relay.recvfrom(65_536)
        log_bulk('turn-server', :recv, "#{pip}:#{pport}", d, alloc[:agg],
                 note: "arrived on relay port #{relay_port}")
        unless alloc[:permissions].include?(pip)
          $stdout.write("[turn-server] DROP: no permission for #{pip} on relay #{relay_port}\n\n")
          next
        end
        ind = Stun.build(Stun::DATA_INDICATION, Stun.new_txid, [
          [Stun::ATTR_XOR_PEER_ADDRESS, Stun.xor_address(pip, pport)],
          [Stun::ATTR_DATA, d],
        ])
        if VERBOSE || ind.bytesize <= BULK
          PacketLog.log('turn-server', :send, client_key, ind,
                        note: 'wrapped as Data Indication for allocation owner')
        end
        control.send(ind, 0, sip, sport)
      end
    rescue IOError
    end

    resp = Stun.build(Stun::ALLOCATE_SUCCESS, msg[:txid], [
      [Stun::ATTR_XOR_RELAYED_ADDRESS, Stun.xor_address(ADVERTISED_IP, relay_port)],
      [Stun::ATTR_XOR_MAPPED_ADDRESS, Stun.xor_address(sip, sport)],
      [Stun::ATTR_LIFETIME, [600].pack('N')],
    ])
    PacketLog.log('turn-server', :send, client_key, resp,
                  note: "allocated relay #{ADVERTISED_IP}:#{relay_port} for #{client_key}")
    control.send(resp, 0, sip, sport)

  when Stun::CREATE_PERMISSION_REQ
    PacketLog.log('turn-server', :recv, client_key, data)
    alloc = allocations[client_key]
    next unless alloc
    peer_ip, = Stun.unxor_address(Stun.attr(msg, Stun::ATTR_XOR_PEER_ADDRESS))
    alloc[:permissions] << peer_ip
    resp = Stun.build(Stun::CREATE_PERMISSION_OK, msg[:txid])
    PacketLog.log('turn-server', :send, client_key, resp,
                  note: "permission granted for peer IP #{peer_ip}")
    control.send(resp, 0, sip, sport)

  when Stun::SEND_INDICATION
    alloc = allocations[client_key]
    next unless alloc
    log_bulk('turn-server', :recv, client_key, data, alloc[:agg])
    peer_ip, peer_port = Stun.unxor_address(Stun.attr(msg, Stun::ATTR_XOR_PEER_ADDRESS))
    payload = Stun.attr(msg, Stun::ATTR_DATA) || ''
    alloc[:relay].send(payload, 0, peer_ip, peer_port)

  else
    PacketLog.log('turn-server', :recv, client_key, data)
    unless Rendezvous.handle('turn-server', control, msg, sip, sport)
      $stdout.write(format("[turn-server] unhandled message type 0x%04x\n", msg[:type]))
    end
  end
rescue Interrupt
  break
rescue => e
  warn "[turn-server] error: #{e.class}: #{e.message}"
end
