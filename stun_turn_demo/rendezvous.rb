# Rendezvous: the "mediation" part of the demo servers.
#
# Real STUN/TURN servers don't introduce peers to each other — that's the
# job of an application signaling server (websockets etc. in WebRTC). Here
# we fold it into the server with two demo extension messages so a single
# server process can mediate:
#
#   peer ── REGISTER(USERNAME "room/name" [, XOR-RELAYED-ADDRESS]) ──> server
#   peer <── REGISTER Success(XOR-MAPPED-ADDRESS) ── server
#   ...when another peer registers in the same room...
#   peer <── PEER-INFO Indication(USERNAME, XOR-PEER-ADDRESS
#                                 [, XOR-RELAYED-ADDRESS]) ── server
require_relative 'stun_message'

module Rendezvous
  @rooms = Hash.new { |h, k| h[k] = {} } # room => { name => entry }

  # Returns true if the message was handled.
  def self.handle(role, sock, msg, sip, sport)
    case msg[:type]
    when Stun::BINDING_REQUEST
      resp = Stun.build(Stun::BINDING_SUCCESS, msg[:txid], [
        [Stun::ATTR_XOR_MAPPED_ADDRESS, Stun.xor_address(sip, sport)],
        [Stun::ATTR_SOFTWARE, "ruby-demo-#{role}"],
      ])
      PacketLog.log(role, :send, "#{sip}:#{sport}", resp,
                    note: "reflexive address is #{sip}:#{sport}")
      sock.send(resp, 0, sip, sport)
      true

    when Stun::REGISTER_REQUEST
      room, name = (Stun.attr(msg, Stun::ATTR_USERNAME) || '/').split('/', 2)
      relay_attr = Stun.attr(msg, Stun::ATTR_XOR_RELAYED_ADDRESS)
      entry = { name: name, ip: sip, port: sport,
                relay: relay_attr && Stun.unxor_address(relay_attr) }
      known = @rooms[room].key?(name)
      @rooms[room][name] = entry
      others = @rooms[room].values.reject { |e| e[:name] == name }

      note = others.empty? ? "'#{name}' registered, waiting for a peer" \
                           : "'#{name}' registered, introducing peers"
      resp = Stun.build(Stun::REGISTER_SUCCESS, msg[:txid], [
        [Stun::ATTR_XOR_MAPPED_ADDRESS, Stun.xor_address(sip, sport)],
        [Stun::ATTR_SOFTWARE, note],
      ])
      PacketLog.log(role, :send, "#{sip}:#{sport}", resp, note: note) unless known
      sock.send(resp, 0, sip, sport)

      unless known # don't re-announce on keepalive re-registrations
        others.each do |other|
          send_peer_info(role, sock, other, entry) # tell existing peer about newcomer
          send_peer_info(role, sock, entry, other) # tell newcomer about existing peer
        end
      end
      true

    else
      false
    end
  end

  def self.send_peer_info(role, sock, to, about)
    attrs = [
      [Stun::ATTR_USERNAME, about[:name]],
      [Stun::ATTR_XOR_PEER_ADDRESS, Stun.xor_address(about[:ip], about[:port])],
    ]
    attrs << [Stun::ATTR_XOR_RELAYED_ADDRESS, Stun.xor_address(*about[:relay])] if about[:relay]
    pkt = Stun.build(Stun::PEER_INFO_INDICATION, Stun.new_txid, attrs)
    PacketLog.log(role, :send, "#{to[:ip]}:#{to[:port]}", pkt,
                  note: "introducing '#{about[:name]}' to '#{to[:name]}'")
    sock.send(pkt, 0, to[:ip], to[:port])
  end
end
