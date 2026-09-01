#!/usr/bin/env ruby
# Interactive P2P peer.
#
# Direct (STUN) mode — server only mediates, data flows peer-to-peer:
#   terminal 1:  ruby stun_server.rb
#   terminal 2:  ruby peer.rb --name alice --room demo
#   terminal 3:  ruby peer.rb --name bob   --room demo
#
# Relayed (TURN) mode — all data flows through the server's relay ports:
#   terminal 1:  ruby turn_server.rb
#   terminal 2:  ruby peer.rb --name alice --room demo --turn
#   terminal 3:  ruby peer.rb --name bob   --room demo --turn
#
# Handshake: STUN Binding (learn own address) -> [TURN Allocate] ->
# REGISTER into room -> server sends PEER-INFO with the other side's
# address -> UDP hole punching -> interactive console:
#
#   /send <text>       chat (plain text without a command also sends)
#   /sendfile <path>   any file — chunked over UDP with retransmission
#   /status            connection info + stats
#   /quit
require_relative 'stun_message'
require 'json'
require 'optparse'
require 'fileutils'

$stdout.sync = true

class Peer
  CHUNK_SIZE = 1024
  FRAME_MAGIC = 'P2' # our tiny app protocol on top of the P2P channel

  HELP = <<~TXT
    commands:
      /send <text>       send a chat message (plain text also works)
      /sendfile <path>   send any file (text / image / video ...)
      /status            show connection info and transfer stats
      /quit              exit
  TXT

  def initialize(opts)
    @name    = opts[:name]
    @room    = opts[:room]
    @turn    = opts[:turn]
    @verbose = opts[:verbose]
    host, port = (opts[:server] || (@turn ? '127.0.0.1:3479' : '127.0.0.1:3478')).split(':')
    @server = [host, (port || 3478).to_i]

    @sock = UDPSocket.new
    @sock.bind('0.0.0.0', 0) # one socket for STUN, TURN and P2P data
    @responses   = Queue.new  # success responses, popped by request()
    @quiet_txids = {}
    @lock        = Mutex.new
    @peer_cv     = ConditionVariable.new
    @peer        = nil        # { name:, mapped: [ip, port], relay: [ip, port] | nil }
    @mapped      = nil
    @relay       = nil
    @connected   = false
    @incoming    = {}         # transfer id => receive state
    @outgoing    = {}         # transfer id => send state
    @completed   = {}
    @stats       = Hash.new(0)
    @punch_logged = {}
  end

  def run
    Thread.new { recv_loop }
    stun_binding
    turn_allocate if @turn
    register
    wait_for_peer
    create_permission if @turn
    punch
    Thread.new { keepalive_loop }
    console
  ensure
    @sock.close rescue nil
  end

  # ---------------------------------------------------------- handshake

  def stun_binding
    resp = request(Stun::BINDING_REQUEST,
                   [[Stun::ATTR_SOFTWARE, "ruby-demo-#{@name}"]],
                   note: 'STUN: what is my public address?')
    @mapped = Stun.unxor_address(Stun.attr(resp, Stun::ATTR_XOR_MAPPED_ADDRESS))
    puts "[#{@name}] my reflexive (public) address: #{@mapped.join(':')}"
  end

  def turn_allocate
    resp = request(Stun::ALLOCATE_REQUEST, [
                     [Stun::ATTR_REQUESTED_TRANSPORT, [17, 0, 0, 0].pack('C4')], # 17 = UDP
                     [Stun::ATTR_LIFETIME, [600].pack('N')],
                   ], note: 'TURN: rent me a relay address')
    @relay = Stun.unxor_address(Stun.attr(resp, Stun::ATTR_XOR_RELAYED_ADDRESS))
    puts "[#{@name}] my relayed address on the TURN server: #{@relay.join(':')}"
  end

  def register(quiet: false)
    attrs = [[Stun::ATTR_USERNAME, "#{@room}/#{@name}"]]
    # In TURN mode we advertise the relay as our candidate: the other peer
    # sends there, and the relay forwards to us wrapped in Data Indications.
    attrs << [Stun::ATTR_XOR_RELAYED_ADDRESS, Stun.xor_address(*@relay)] if @relay
    resp = request(Stun::REGISTER_REQUEST, attrs, quiet: quiet,
                   note: "join room '#{@room}' as '#{@name}'")
    puts "[#{@name}] server: #{Stun.attr(resp, Stun::ATTR_SOFTWARE)}" unless quiet
  end

  def wait_for_peer
    return if @peer
    puts "[#{@name}] waiting for a peer to join room '#{@room}' ..."
    until @peer
      @lock.synchronize { @peer_cv.wait(@lock, 15) unless @peer }
      # re-register periodically: keeps the NAT mapping to the server alive
      register(quiet: true) unless @peer
    end
  end

  def create_permission
    request(Stun::CREATE_PERMISSION_REQ,
            [[Stun::ATTR_XOR_PEER_ADDRESS, Stun.xor_address(*@peer[:mapped])]],
            note: "TURN: allow #{@peer[:name]}'s IP to reach my relay")
  end

  def punch
    puts "[#{@name}] hole punching toward #{target_s} ..."
    40.times do
      break if @connected
      send_raw(hello_frame)
      sleep 0.5
    end
    puts "[#{@name}] punch timed out — peer unreachable" unless @connected
  end

  def hello_frame
    unless @punch_logged[:send]
      @punch_logged[:send] = true
      PacketLog.log(@name, :send, target_s, frame('H', @name),
                    note: 'hole punch hello (repeats until answered)')
    end
    frame('H', @name)
  end

  # Sends a request to the server and waits for the matching success response.
  def request(type, attrs = [], note: nil, quiet: false)
    txid = Stun.new_txid
    pkt = Stun.build(type, txid, attrs)
    @quiet_txids[txid] = true if quiet
    PacketLog.log(@name, :send, "#{@server[0]}:#{@server[1]}", pkt, note: note) unless quiet
    @sock.send(pkt, 0, *@server)
    deadline = Time.now + 5
    begin
      @responses.pop(true)
    rescue ThreadError
      abort "[#{@name}] no response from server #{@server.join(':')} — is it running?" if Time.now > deadline
      sleep 0.05
      retry
    end
  end

  # ---------------------------------------------------------- receive path

  def recv_loop
    loop do
      data, (_, sport, _, sip) = @sock.recvfrom(65_536)
      from = "#{sip}:#{sport}"
      if Stun.stun_packet?(data)
        msg = Stun.parse(data)
        case msg[:type]
        when Stun::PEER_INFO_INDICATION
          PacketLog.log(@name, :recv, from, data, note: 'peer introduction from server')
          handle_peer_info(msg)
        when Stun::DATA_INDICATION
          payload = Stun.attr(msg, Stun::ATTR_DATA) || ''
          log_frame(:recv, "#{from} (Data Indication via my relay)", data, payload)
          handle_frame(payload)
        else
          if Stun.success_response?(msg[:type])
            PacketLog.log(@name, :recv, from, data) unless @quiet_txids.delete(msg[:txid])
            @responses << msg
          else
            PacketLog.log(@name, :recv, from, data, note: 'unexpected')
          end
        end
      else
        log_frame(:recv, from, data, data)
        handle_frame(data)
      end
    end
  rescue IOError, Errno::EBADF
    # socket closed on shutdown
  end

  def handle_peer_info(msg)
    name = Stun.attr(msg, Stun::ATTR_USERNAME)
    mapped = Stun.unxor_address(Stun.attr(msg, Stun::ATTR_XOR_PEER_ADDRESS))
    relay_attr = Stun.attr(msg, Stun::ATTR_XOR_RELAYED_ADDRESS)
    relay = relay_attr && Stun.unxor_address(relay_attr)
    @lock.synchronize do
      @peer = { name: name, mapped: mapped, relay: relay }
      @peer_cv.broadcast
    end
    puts "[#{@name}] room '#{@room}': peer '#{name}' is at #{mapped.join(':')}" \
         "#{relay ? " (their relay: #{relay.join(':')})" : ''} — sending to #{target_s}"
  end

  def handle_frame(data)
    return unless data[0, 2] == FRAME_MAGIC
    type = data[2]
    payload = data[3..] || ''
    mark_connected unless type == 'H'
    case type
    when 'H' # hole punch hello
      unless @connected
        mark_connected
        send_raw(frame('H', @name)) # answer so the other side connects too
      end
    when 'M' # chat message
      m = JSON.parse(payload)
      puts "\n[#{m['from']}] says: #{m['text']}"
    when 'P' then send_raw(frame('O', '')) # keepalive ping
    when 'O' # keepalive pong
    when 'F' then handle_file_header(payload)
    when 'C' then handle_chunk(payload)
    when 'E' then handle_transfer_end(payload)
    when 'R' then handle_resend_request(payload)
    when 'D' # receiver confirmed: transfer complete
      st = @outgoing[JSON.parse(payload)['id']]
      st[:done] = true if st
    end
  rescue => e
    warn "[#{@name}] bad frame (#{e.class}: #{e.message})"
  end

  def mark_connected
    return if @connected
    @connected = true
    puts "\n[#{@name}] *** P2P channel to '#{@peer && @peer[:name]}' established" \
         "#{@turn ? ' (via TURN relay)' : ' (direct, no server in the path)'} ***\n\n"
  end

  # ---------------------------------------------------------- app protocol
  #
  # Tiny frame format on top of UDP: "P2" + 1 type byte + payload
  #   H hello/punch   M chat(json)       P/O keepalive ping/pong
  #   F file header(json {id,name,size,chunks})
  #   C chunk(id u32, seq u32, bytes)
  #   E sender finished(json {id})       R resend request(json {id,missing})
  #   D receiver done(json {id})

  def frame(type, payload)
    FRAME_MAGIC + type + payload
  end

  def target # where we send app data: peer's relay if they have one
    @peer && (@peer[:relay] || @peer[:mapped])
  end

  def target_s
    (t = target) ? "#{t[0]}:#{t[1]}" : '(no peer yet)'
  end

  def send_raw(data)
    t = target or return
    @sock.send(data, 0, *t)
  end

  def send_text(text)
    pkt = frame('M', JSON.generate(from: @name, text: text))
    log_frame(:send, target_s, pkt, pkt)
    send_raw(pkt)
  end

  def send_file(path)
    unless File.file?(path)
      puts "no such file: #{path}"
      return
    end
    io = File.open(path, 'rb')
    size = io.size
    count = (size + CHUNK_SIZE - 1) / CHUNK_SIZE
    id = rand(2**32)
    st = { io: io, size: size, count: count, done: false, name: File.basename(path) }
    @outgoing[id] = st

    header = frame('F', JSON.generate(id: id, name: st[:name], size: size, chunks: count))
    PacketLog.log(@name, :send, target_s, header, note: 'file transfer header')
    send_raw(header)

    t0 = Time.now
    count.times do |seq|
      send_chunk(id, seq)
      sleep 0.001 if (seq % 64).zero? # crude pacing so we don't overrun buffers
      puts "[#{@name}] sent #{seq + 1}/#{count} chunks ..." if ((seq + 1) % 2000).zero?
    end

    # Tell the receiver we're done; it answers R (resend these) or D (done).
    # Header is resent too in case the F packet itself was lost.
    60.times do
      break if st[:done]
      send_raw(header)
      send_raw(frame('E', JSON.generate(id: id)))
      5.times do
        sleep 0.2
        break if st[:done]
      end
    end

    if st[:done]
      secs = [Time.now - t0, 0.001].max
      puts format("[#{@name}] file '%s' delivered: %d bytes in %.2fs (%.2f MB/s), %d chunks retransmitted",
                  st[:name], size, secs, size / secs / 1e6, @stats[:chunks_retransmitted])
    else
      puts "[#{@name}] transfer was never acknowledged — is the peer still there?"
    end
  ensure
    @outgoing.delete(id) if id
    io&.close
  end

  def send_chunk(id, seq)
    st = @outgoing[id] or return
    len = [CHUNK_SIZE, st[:size] - seq * CHUNK_SIZE].min
    data = st[:io].pread(len, seq * CHUNK_SIZE)
    send_raw(frame('C', [id, seq].pack('NN') + data))
    @stats[:chunks_sent] += 1
  end

  def handle_file_header(payload)
    h = JSON.parse(payload)
    id = h['id']
    return if @incoming[id] || @completed[id] # duplicate header
    @incoming[id] = { name: h['name'], size: h['size'], count: h['chunks'],
                      chunks: Array.new(h['chunks']), got: 0, t0: Time.now }
    puts "[#{@name}] incoming file '#{h['name']}' (#{h['size']} bytes, #{h['chunks']} chunks) from '#{@peer[:name]}'"
  end

  def handle_chunk(payload)
    id, seq = payload.unpack('NN')
    st = @incoming[id] or return
    return unless st[:chunks][seq].nil?
    st[:chunks][seq] = payload[8..] || ''
    st[:got] += 1
    @stats[:chunks_received] += 1
    puts "[#{@name}] received #{st[:got]}/#{st[:count]} chunks ..." if (st[:got] % 2000).zero?
  end

  def handle_transfer_end(payload)
    id = JSON.parse(payload)['id']
    if @completed[id] # already saved; sender missed our D — resend it
      send_raw(frame('D', JSON.generate(id: id)))
      return
    end
    st = @incoming[id] or return
    missing = (0...st[:count]).select { |i| st[:chunks][i].nil? }
    if missing.empty?
      finish_incoming(id, st)
    else
      puts "[#{@name}] #{missing.size} chunks missing — requesting retransmit"
      send_raw(frame('R', JSON.generate(id: id, missing: missing.first(800))))
    end
  end

  def handle_resend_request(payload)
    req = JSON.parse(payload)
    id = req['id']
    return unless @outgoing[id]
    @stats[:chunks_retransmitted] += req['missing'].size
    req['missing'].each_with_index do |seq, i|
      send_chunk(id, seq)
      sleep 0.001 if (i % 64).zero?
    end
    send_raw(frame('E', JSON.generate(id: id)))
  end

  def finish_incoming(id, st)
    FileUtils.mkdir_p('downloads')
    dest = File.join('downloads', st[:name])
    dest = File.join('downloads', "#{Time.now.to_i}_#{st[:name]}") if File.exist?(dest)
    File.binwrite(dest, st[:chunks].join)
    @incoming.delete(id)
    @completed[id] = true
    send_raw(frame('D', JSON.generate(id: id)))
    secs = [Time.now - st[:t0], 0.001].max
    puts format("[#{@name}] file saved to %s (%d bytes in %.2fs, %.2f MB/s)",
                dest, st[:size], secs, st[:size] / secs / 1e6)
  end

  # ---------------------------------------------------------- housekeeping

  def keepalive_loop
    loop do
      sleep 15
      send_raw(frame('P', '')) if @connected # keeps NAT bindings warm
    end
  end

  # Log app frames; bulk/noisy types (chunks, keepalives, repeated punches)
  # are skipped unless --verbose.
  def log_frame(dir, remote, raw, payload)
    type = payload[0, 2] == FRAME_MAGIC ? payload[2] : nil
    unless @verbose
      return if %w[C P O R].include?(type)
      if type == 'H'
        return if @punch_logged[dir]
        @punch_logged[dir] = true
      end
    end
    PacketLog.log(@name, dir, remote, raw)
  end

  def show_status
    puts <<~TXT
      name:       #{@name}   room: #{@room}   mode: #{@turn ? 'TURN relay' : 'direct P2P'}
      server:     #{@server.join(':')}
      reflexive:  #{@mapped ? @mapped.join(':') : '-'}
      my relay:   #{@relay ? @relay.join(':') : '-'}
      peer:       #{@peer ? "#{@peer[:name]} @ #{target_s}#{@peer[:relay] ? ' (their relay)' : ''}" : '(none yet)'}
      connected:  #{@connected}
      stats:      #{@stats.empty? ? '-' : @stats.map { |k, v| "#{k}=#{v}" }.join('  ')}
    TXT
  end

  def console
    puts HELP
    while (line = $stdin.gets)
      line = line.chomp.strip
      case line
      when '' then next
      when '/quit', '/q' then break
      when '/status' then show_status
      when '/help' then puts HELP
      when %r{\A/sendfile\s+(.+)\z} then send_file(Regexp.last_match(1).strip)
      when %r{\A/send\s+(.+)\z}m then send_text(Regexp.last_match(1))
      when %r{\A/} then puts "unknown command\n#{HELP}"
      else send_text(line)
      end
    end
    puts "[#{@name}] bye"
  end
end

opts = { name: "peer-#{rand(36**4).to_s(36)}", room: 'demo', turn: false, verbose: false, server: nil }
OptionParser.new do |o|
  o.banner = 'usage: ruby peer.rb [--name NAME] [--room ROOM] [--server HOST:PORT] [--turn] [--verbose]'
  o.on('--name NAME', 'peer name (default: random)') { |v| opts[:name] = v }
  o.on('--room ROOM', "rendezvous room, must match the other peer (default 'demo')") { |v| opts[:room] = v }
  o.on('--server HOST:PORT', 'server address (default 127.0.0.1:3478, or :3479 with --turn)') { |v| opts[:server] = v }
  o.on('--turn', 'relay all traffic through the TURN server instead of direct P2P') { opts[:turn] = true }
  o.on('--verbose', 'hexdump every packet, including file chunks and keepalives') { opts[:verbose] = true }
end.parse!

trap('INT') { exit }
Peer.new(opts).run
