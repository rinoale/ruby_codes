# Minimal STUN/TURN wire-format library (RFC 5389 / RFC 5766, no auth),
# plus two demo-only extension messages for rendezvous (REGISTER/PEER-INFO).
#
# STUN message layout:
#
#   0                   1                   2                   3
#   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
#  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#  |0 0|  Message Type (14 bit)  |        Message Length           |
#  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#  |                  Magic Cookie = 0x2112A442                    |
#  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#  |                 Transaction ID (96 bits)                      |
#  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#  |            Attributes (TLV, padded to 4 bytes) ...            |
#
require 'socket'
require 'ipaddr'
require 'securerandom'

module Stun
  MAGIC_COOKIE = 0x2112A442

  # Standard message types (class + method bits combined, as on the wire)
  BINDING_REQUEST       = 0x0001
  BINDING_SUCCESS       = 0x0101
  ALLOCATE_REQUEST      = 0x0003 # TURN
  ALLOCATE_SUCCESS      = 0x0103
  CREATE_PERMISSION_REQ = 0x0008
  CREATE_PERMISSION_OK  = 0x0108
  SEND_INDICATION       = 0x0016 # client -> TURN, "relay this to peer"
  DATA_INDICATION       = 0x0017 # TURN -> client, "peer sent you this"

  # Demo-only rendezvous extension (NOT standard STUN — plays the role a
  # signaling server plays in WebRTC): peers join a room, the server
  # introduces them to each other.
  REGISTER_REQUEST      = 0x0042 # request class (0b00)
  REGISTER_SUCCESS      = 0x0142 # success class
  PEER_INFO_INDICATION  = 0x0052 # indication class (0x0010 bit set)

  TYPE_NAMES = {
    BINDING_REQUEST       => 'STUN Binding Request',
    BINDING_SUCCESS       => 'STUN Binding Success Response',
    ALLOCATE_REQUEST      => 'TURN Allocate Request',
    ALLOCATE_SUCCESS      => 'TURN Allocate Success Response',
    CREATE_PERMISSION_REQ => 'TURN CreatePermission Request',
    CREATE_PERMISSION_OK  => 'TURN CreatePermission Success Response',
    SEND_INDICATION       => 'TURN Send Indication',
    DATA_INDICATION       => 'TURN Data Indication',
    REGISTER_REQUEST      => 'REGISTER Request (demo rendezvous ext.)',
    REGISTER_SUCCESS      => 'REGISTER Success Response (demo ext.)',
    PEER_INFO_INDICATION  => 'PEER-INFO Indication (demo ext.)',
  }.freeze

  # Attribute types
  ATTR_USERNAME            = 0x0006
  ATTR_XOR_PEER_ADDRESS    = 0x0012
  ATTR_DATA                = 0x0013
  ATTR_XOR_RELAYED_ADDRESS = 0x0016
  ATTR_XOR_MAPPED_ADDRESS  = 0x0020
  ATTR_LIFETIME            = 0x000D
  ATTR_REQUESTED_TRANSPORT = 0x0019
  ATTR_SOFTWARE            = 0x8022

  ATTR_NAMES = {
    ATTR_USERNAME            => 'USERNAME',
    ATTR_XOR_PEER_ADDRESS    => 'XOR-PEER-ADDRESS',
    ATTR_DATA                => 'DATA',
    ATTR_XOR_RELAYED_ADDRESS => 'XOR-RELAYED-ADDRESS',
    ATTR_XOR_MAPPED_ADDRESS  => 'XOR-MAPPED-ADDRESS',
    ATTR_LIFETIME            => 'LIFETIME',
    ATTR_REQUESTED_TRANSPORT => 'REQUESTED-TRANSPORT',
    ATTR_SOFTWARE            => 'SOFTWARE',
  }.freeze

  module_function

  def new_txid
    SecureRandom.random_bytes(12)
  end

  # attrs: array of [attr_type, value_bytes]
  def build(type, txid, attrs = [])
    body = attrs.map do |t, v|
      pad = (4 - v.bytesize % 4) % 4
      [t, v.bytesize].pack('nn') + v + "\x00" * pad
    end.join
    [type, body.bytesize, MAGIC_COOKIE].pack('nnN') + txid + body
  end

  def parse(data)
    type, len, _cookie = data.unpack('nnN')
    txid = data[8, 12]
    attrs = []
    off = 20
    while off < 20 + len
      at, alen = data[off, 4].unpack('nn')
      attrs << [at, data[off + 4, alen]]
      off += 4 + alen + ((4 - alen % 4) % 4)
    end
    { type: type, txid: txid, attrs: attrs }
  end

  def attr(msg, type)
    pair = msg[:attrs].find { |t, _| t == type }
    pair && pair[1]
  end

  def success_response?(type)
    (type & 0x0100) != 0
  end

  # Addresses are XOR'd with the magic cookie so NATs that rewrite
  # literal IP addresses in payloads can't corrupt them.
  def xor_address(ip, port)
    x_port = port ^ (MAGIC_COOKIE >> 16)
    x_ip   = IPAddr.new(ip).to_i ^ MAGIC_COOKIE
    [0, 0x01, x_port, x_ip].pack('CCnN') # reserved, family=IPv4, port, addr
  end

  def unxor_address(bytes)
    _, _family, x_port, x_ip = bytes.unpack('CCnN')
    [IPAddr.new(x_ip ^ MAGIC_COOKIE, Socket::AF_INET).to_s,
     x_port ^ (MAGIC_COOKIE >> 16)]
  end

  def stun_packet?(data)
    data.bytesize >= 20 && data.unpack1('@4N') == MAGIC_COOKIE
  end

  def describe(data)
    msg = parse(data)
    name = TYPE_NAMES[msg[:type]] || format('unknown type 0x%04x', msg[:type])
    lines = ["#{name}  (#{data.bytesize} bytes, txid=#{msg[:txid].unpack1('H*')})"]
    msg[:attrs].each do |t, v|
      aname = ATTR_NAMES[t] || format('attr-0x%04x', t)
      lines << format('  %-22s %s', aname, describe_attr(t, v))
    end
    lines
  end

  def describe_attr(type, value)
    case type
    when ATTR_XOR_MAPPED_ADDRESS, ATTR_XOR_PEER_ADDRESS, ATTR_XOR_RELAYED_ADDRESS
      ip, port = unxor_address(value)
      "#{ip}:#{port}  (xor-encoded on the wire as #{value.unpack1('H*')})"
    when ATTR_DATA
      value.bytesize > 64 ? "#{value.bytesize} bytes: #{value[0, 32].inspect}..." : value.inspect
    when ATTR_LIFETIME
      "#{value.unpack1('N')} seconds"
    when ATTR_REQUESTED_TRANSPORT
      proto = value.unpack1('C')
      "#{proto}#{proto == 17 ? ' (UDP)' : ''}"
    when ATTR_SOFTWARE, ATTR_USERNAME
      value.inspect
    else
      value.unpack1('H*')
    end
  end

  def hexdump(data, indent: '    ', max_bytes: 512)
    truncated = data.bytesize > max_bytes
    lines = data[0, max_bytes].bytes.each_slice(16).each_with_index.map do |chunk, i|
      hex = chunk.each_slice(8).map { |g| g.map { |b| format('%02x', b) }.join(' ') }.join('  ')
      ascii = chunk.map { |b| (32..126).cover?(b) ? b.chr : '.' }.join
      format('%s%04x  %-49s |%s|', indent, i * 16, hex, ascii)
    end
    lines << "#{indent}... (#{data.bytesize - max_bytes} more bytes)" if truncated
    lines
  end

  def banner(text)
    $stdout.write("\n#{'=' * 76}\n== #{text}\n#{'=' * 76}\n\n")
  end
end

# Logs one packet as a single $stdout.write so concurrent processes/threads
# don't interleave mid-dump.
module PacketLog
  def self.log(role, dir, remote, data, note: nil)
    arrow = dir == :send ? '--->' : '<---'
    out = +"[#{role}] #{arrow} #{remote}"
    out << "   (#{note})" if note
    out << "\n"
    if Stun.stun_packet?(data)
      Stun.describe(data).each { |l| out << '    ' << l << "\n" }
    else
      preview = data.bytesize > 64 ? "#{data[0, 48].inspect}... (#{data.bytesize} bytes)" : data.inspect
      out << "    raw UDP payload (not STUN): #{preview}\n"
    end
    Stun.hexdump(data).each { |l| out << l << "\n" }
    out << "\n"
    $stdout.write(out)
  end

  # One-line form for bulk traffic (file chunks) so transfers don't flood
  # the terminal with hexdumps.
  def self.brief(role, dir, remote, text)
    arrow = dir == :send ? '--->' : '<---'
    $stdout.write("[#{role}] #{arrow} #{remote}  #{text}\n")
  end
end
