#!/usr/bin/env ruby
# frozen_string_literal: true
#
# tap.rb -- a man-in-the-middle TCP proxy that prints the *actual bytes* of a
# gRPC conversation.
#
#   ruby tap.rb [listen_port] [upstream_host:port]     # default 50052 -> localhost:50051
#
# It forwards bytes untouched, and in parallel decodes them as:
#
#   TCP bytes
#     -> HTTP/2 connection preface + frames   (9-byte header: len|type|flags|stream)
#        -> HEADERS frames  -> HPACK (static/dynamic table + Huffman)  -> :path, grpc-status, ...
#        -> DATA frames     -> gRPC length-prefixed messages (1-byte flag + 4-byte length)
#                              -> protobuf wire format (tag = field<<3 | wire_type)
#
# Nothing here is gRPC-library magic: it is all just parsing the bytes.
#
# Env knobs:  TAP_MAX_HEX=0 (no cap) | N bytes per hexdump (default 96)
#             TAP_QUIET=1 hides PING / WINDOW_UPDATE / SETTINGS-ACK housekeeping
#             NO_COLOR=1 to disable ANSI colour

require 'socket'
require 'stringio'
require_relative 'hpack_huffman'

MAX_HEX = (ENV['TAP_MAX_HEX'] || '96').to_i
QUIET   = ENV['TAP_QUIET'] == '1'
COLOR   = $stdout.tty? && !ENV['NO_COLOR']

def c(text, code) = COLOR ? "\e[#{code}m#{text}\e[0m" : text
def dim(t)  = c(t, 90)
def bold(t) = c(t, 1)

OUT = Mutex.new
def emit(lines) = OUT.synchronize { puts Array(lines); $stdout.flush }

# --------------------------------------------------------------------------
# hex dump
# --------------------------------------------------------------------------
def hexdump(bytes, indent = '     ')
  return [] if bytes.empty?

  shown = MAX_HEX.positive? ? bytes[0, MAX_HEX] : bytes
  lines = shown.bytes.each_slice(16).with_index.map do |row, i|
    hex = row.map { |b| format('%02x', b) }.each_slice(8).map { |h| h.join(' ') }.join('  ')
    asc = row.map { |b| (32..126).cover?(b) ? b.chr : '.' }.join
    format('%s%04x  %-49s |%s|', indent, i * 16, hex, asc)
  end
  lines << "#{indent}      ... #{bytes.bytesize - shown.bytesize} more bytes" if shown.bytesize < bytes.bytesize
  lines.map { |l| dim(l) }
end

# --------------------------------------------------------------------------
# protobuf wire format (schema-free: the bytes tell you everything)
# --------------------------------------------------------------------------
module Proto
  WIRE = { 0 => 'VARINT', 1 => 'I64', 2 => 'LEN', 5 => 'I32' }.freeze

  def self.varint(io)
    val = 0
    shift = 0
    loop do
      b = io.getbyte or return nil
      val |= (b & 0x7f) << shift
      return val if b < 0x80

      shift += 7
      return nil if shift > 63
    end
  end

  # Returns an array of printable lines, or nil if `data` is not valid protobuf.
  def self.decode(data, depth = 0)
    io = StringIO.new(data)
    lines = []
    pad = '  ' * depth
    until io.eof?
      tag = varint(io) or return nil
      field = tag >> 3
      wire  = tag & 7
      return nil if field.zero? || !WIRE.key?(wire)

      case wire
      when 0
        v = varint(io) or return nil
        lines << format('%sfield %-2d %-7s = %d', pad, field, WIRE[wire], v)
      when 1
        raw = io.read(8)
        return nil if raw.nil? || raw.bytesize < 8

        lines << format('%sfield %-2d %-7s = 0x%s (double %g)', pad, field, WIRE[wire],
                        raw.unpack1('H*'), raw.unpack1('E'))
      when 5
        raw = io.read(4)
        return nil if raw.nil? || raw.bytesize < 4

        lines << format('%sfield %-2d %-7s = 0x%s (float %g)', pad, field, WIRE[wire],
                        raw.unpack1('H*'), raw.unpack1('e'))
      when 2
        len = varint(io) or return nil
        raw = io.read(len)
        return nil if raw.nil? || raw.bytesize < len

        lines.concat(len_field(pad, field, raw, depth))
      end
    end
    lines
  end

  def self.len_field(pad, field, raw, depth)
    head = format('%sfield %-2d %-7s (%d bytes)', pad, field, 'LEN', raw.bytesize)
    str = raw.dup.force_encoding('UTF-8')
    if str.valid_encoding? && str.match?(/\A[[:print:][:space:]]*\z/) && !raw.empty?
      ["#{head} = #{str.inspect}"]
    elsif (nested = decode(raw, depth + 1))
      ["#{head} = nested message {", *nested, "#{pad}}"]
    else
      ["#{head} = 0x#{raw.unpack1('H*')}"]
    end
  end
end

# --------------------------------------------------------------------------
# HPACK (RFC 7541) decoder -- one instance per direction, it is stateful
# --------------------------------------------------------------------------
class Hpack
  STATIC = [
    nil, [':authority', ''], [':method', 'GET'], [':method', 'POST'], [':path', '/'],
    [':path', '/index.html'], [':scheme', 'http'], [':scheme', 'https'], [':status', '200'],
    [':status', '204'], [':status', '206'], [':status', '304'], [':status', '400'],
    [':status', '404'], [':status', '500'], ['accept-charset', ''],
    ['accept-encoding', 'gzip, deflate'], ['accept-language', ''], ['accept-ranges', ''],
    ['accept', ''], ['access-control-allow-origin', ''], ['age', ''], ['allow', ''],
    ['authorization', ''], ['cache-control', ''], ['content-disposition', ''],
    ['content-encoding', ''], ['content-language', ''], ['content-length', ''],
    ['content-location', ''], ['content-range', ''], ['content-type', ''], ['cookie', ''],
    ['date', ''], ['etag', ''], ['expect', ''], ['expires', ''], ['from', ''], ['host', ''],
    ['if-match', ''], ['if-modified-since', ''], ['if-none-match', ''], ['if-range', ''],
    ['if-unmodified-since', ''], ['last-modified', ''], ['link', ''], ['location', ''],
    ['max-forwards', ''], ['proxy-authenticate', ''], ['proxy-authorization', ''],
    ['range', ''], ['referer', ''], ['refresh', ''], ['retry-after', ''], ['server', ''],
    ['set-cookie', ''], ['strict-transport-security', ''], ['transfer-encoding', ''],
    ['user-agent', ''], ['vary', ''], ['via', ''], ['www-authenticate', '']
  ].freeze

  # Huffman decoding tree, built once from the RFC 7541 code table.
  TREE = begin
    root = [nil, nil]
    HPACK_HUFFMAN.each_with_index do |(code, bits), sym|
      node = root
      (bits - 1).downto(0) do |i|
        bit = (code >> i) & 1
        if i.zero?
          node[bit] = sym
        else
          node[bit] ||= [nil, nil]
          node = node[bit]
        end
      end
    end
    root.freeze
  end

  def self.huffman(bytes)
    out = +''
    node = TREE
    bytes.each_byte do |byte|
      7.downto(0) do |i|
        node = node[(byte >> i) & 1]
        return out if node.nil?          # malformed -> give up gracefully

        if node.is_a?(Integer)
          return out if node == 256      # EOS

          out << node.chr
          node = TREE
        end
      end
    end
    out.force_encoding('UTF-8')
  end

  def initialize = @dynamic = []

  def lookup(idx)
    return STATIC[idx] if idx <= 61

    @dynamic[idx - 62] || ['?', '?']
  end

  # Decodes one header block, returns [[name, value, note], ...]
  def decode(block)
    io = StringIO.new(block)
    headers = []
    until io.eof?
      b = io.getbyte
      if b & 0x80 == 0x80                       # 1xxxxxxx indexed header field
        idx = int(io, b, 7)
        n, v = lookup(idx)
        headers << [n, v, "indexed(#{idx})"]
      elsif b & 0xc0 == 0x40                    # 01xxxxxx literal, add to dynamic table
        n, v = literal(io, b, 6)
        @dynamic.unshift([n, v])
        evict
        headers << [n, v, 'literal+index']
      elsif b & 0xe0 == 0x20                    # 001xxxxx dynamic table size update
        headers << ['(dynamic table size update)', int(io, b, 5).to_s, '']
      else                                      # 0000xxxx / 0001xxxx literal, no index
        n, v = literal(io, b, 4)
        headers << [n, v, b & 0x10 == 0x10 ? 'literal never-index' : 'literal']
      end
    end
    headers
  rescue StandardError => e
    [['(hpack decode failed)', e.message, '']]
  end

  private

  def int(io, first, prefix)
    mask = (1 << prefix) - 1
    val = first & mask
    return val if val < mask

    shift = 0
    loop do
      b = io.getbyte
      val += (b & 0x7f) << shift
      return val if b < 0x80

      shift += 7
    end
  end

  def string(io)
    b = io.getbyte
    huff = b & 0x80 == 0x80
    len = int(io, b, 7)
    raw = io.read(len).to_s
    huff ? self.class.huffman(raw) : raw.force_encoding('UTF-8')
  end

  def literal(io, first, prefix)
    idx = int(io, first, prefix)
    name = idx.zero? ? string(io) : lookup(idx)[0]
    [name, string(io)]
  end

  # RFC 7541 4.1: entry size is name + value + 32 bytes of overhead.
  def evict(max = 4096)
    @dynamic.pop while @dynamic.sum { |n, v| n.bytesize + v.bytesize + 32 } > max
  end
end

# --------------------------------------------------------------------------
# HTTP/2 frame parser (one per direction)
# --------------------------------------------------------------------------
class H2Parser
  PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
  TYPES = %w[DATA HEADERS PRIORITY RST_STREAM SETTINGS PUSH_PROMISE PING GOAWAY
             WINDOW_UPDATE CONTINUATION].freeze
  SETTINGS = { 1 => 'HEADER_TABLE_SIZE', 2 => 'ENABLE_PUSH', 3 => 'MAX_CONCURRENT_STREAMS',
               4 => 'INITIAL_WINDOW_SIZE', 5 => 'MAX_FRAME_SIZE', 6 => 'MAX_HEADER_LIST_SIZE',
               65_027 => 'GRPC_ALLOW_TRUE_BINARY_METADATA' }.freeze
  ERRORS = %w[NO_ERROR PROTOCOL_ERROR INTERNAL_ERROR FLOW_CONTROL_ERROR SETTINGS_TIMEOUT
              STREAM_CLOSED FRAME_SIZE_ERROR REFUSED_STREAM CANCEL COMPRESSION_ERROR
              CONNECT_ERROR ENHANCE_YOUR_CALM INADEQUATE_SECURITY HTTP_1_1_REQUIRED].freeze

  def initialize(label, color)
    @label   = label
    @color   = color
    @buf     = +''.b
    @hpack   = Hpack.new
    @preface = false
    @hblock  = {}   # stream -> accumulated header block (HEADERS + CONTINUATION)
    @grpc    = Hash.new { |h, k| h[k] = +''.b }  # stream -> partial gRPC message buffer
  end

  def arrow = c(@label, @color)

  def <<(chunk)
    @buf << chunk
    unless @preface
      return if @buf.bytesize < PREFACE.bytesize && PREFACE.start_with?(@buf)

      if @buf.start_with?(PREFACE)
        @buf = @buf[PREFACE.bytesize..]
        emit ['', "#{arrow} #{bold('HTTP/2 connection preface')} (24 bytes, sent once by the client)",
              *hexdump(PREFACE.b)]
      end
      @preface = true
    end

    loop do
      break if @buf.bytesize < 9

      len = (@buf.getbyte(0) << 16) | (@buf.getbyte(1) << 8) | @buf.getbyte(2)
      break if @buf.bytesize < 9 + len

      header  = @buf[0, 9]
      payload = @buf[9, len]
      @buf    = @buf[(9 + len)..]
      frame(header, payload, len)
    end
  end

  private

  def frame(header, payload, len)
    type   = header.getbyte(3)
    flags  = header.getbyte(4)
    stream = header[5, 4].unpack1('N') & 0x7fffffff
    name   = TYPES[type] || "UNKNOWN(#{type})"
    return if QUIET && (type == 6 || type == 8 || (type == 4 && flags & 1 == 1))

    lines = ['', "#{arrow} #{bold(name)} stream=#{stream} length=#{len} flags=0x#{format('%02x', flags)}#{flag_names(type, flags)}",
             dim("     frame header: #{header.unpack1('H*')}  = len(3B) type(1B) flags(1B) stream-id(4B)")]
    lines.concat(hexdump(payload)) unless payload.empty?
    lines.concat(detail(type, flags, stream, payload))
    emit lines
  end

  def flag_names(type, flags)
    names = []
    case type
    when 0 then names << 'END_STREAM' if flags & 0x1 == 1
    when 1
      names << 'END_STREAM'  if flags & 0x01 == 0x01
      names << 'END_HEADERS' if flags & 0x04 == 0x04
      names << 'PADDED'      if flags & 0x08 == 0x08
      names << 'PRIORITY'    if flags & 0x20 == 0x20
    when 4, 6 then names << 'ACK' if flags & 0x1 == 1
    when 9 then names << 'END_HEADERS' if flags & 0x04 == 0x04
    end
    names.empty? ? '' : " (#{names.join('|')})"
  end

  def detail(type, flags, stream, payload)
    case type
    when 0 then data_frame(stream, flags, payload)
    when 1 then headers_frame(stream, flags, payload)
    when 3 then ["     error code: #{ERRORS[payload.unpack1('N')] || payload.unpack1('N')}"]
    when 4
      return ['     (acknowledgement)'] if flags & 1 == 1

      payload.scan(/.{6}/m).map do |s|
        id, val = s.unpack('nN')
        format('     %-24s = %d', SETTINGS[id] || "SETTING(#{id})", val)
      end
    when 7
      last, code = payload.unpack('NN')
      ["     last-stream-id=#{last & 0x7fffffff} error=#{ERRORS[code] || code} debug=#{payload[8..].inspect}"]
    when 8 then ["     window increment: #{payload.unpack1('N') & 0x7fffffff} bytes"]
    else []
    end
  end

  def headers_frame(stream, flags, payload)
    body = payload.dup
    pad = 0
    if flags & 0x08 == 0x08
      pad = body.getbyte(0)
      body = body[1..]
    end
    body = body[5..] if flags & 0x20 == 0x20   # strip priority (stream dep + weight)
    body = body[0, body.bytesize - pad] if pad.positive?

    (@hblock[stream] ||= +''.b) << body
    return ['     (waiting for CONTINUATION frame)'] unless flags & 0x04 == 0x04

    block = @hblock.delete(stream)
    lines = ["     #{bold('HPACK-decoded headers:')}"]
    @hpack.decode(block).each do |n, v, note|
      lines << format('       %-24s %-46s %s', "#{n}:", v.inspect, dim(note))
    end
    lines
  end

  # A DATA frame payload is a stream of gRPC "length-prefixed messages":
  #   [1 byte compressed-flag][4 byte big-endian length][length bytes of protobuf]
  # A message may straddle several DATA frames, hence the per-stream buffer.
  def data_frame(stream, _flags, payload)
    buf = (@grpc[stream] << payload)
    lines = []
    while buf.bytesize >= 5
      compressed = buf.getbyte(0)
      len = buf[1, 4].unpack1('N')
      break if buf.bytesize < 5 + len

      msg = buf[5, len]
      buf.replace(buf[(5 + len)..])
      lines << "     #{bold('gRPC message frame')}: compressed-flag=#{compressed} " \
               "length=#{len} (prefix bytes #{format('%02x %08x', compressed, len)})"
      lines << dim("     protobuf payload: #{msg.unpack1('H*')}")
      decoded = msg.empty? ? ['(empty message)'] : (Proto.decode(msg) || ['(not decodable as protobuf)'])
      lines.concat(decoded.map { |l| "       #{c(l, 32)}" })
    end
    lines << "     (#{buf.bytesize} bytes buffered, message continues in a later DATA frame)" unless buf.empty?
    lines
  end
end

# --------------------------------------------------------------------------
# the proxy itself
# --------------------------------------------------------------------------
listen_port = (ARGV[0] || 50_052).to_i
up_host, up_port = (ARGV[1] || 'localhost:50051').split(':')

emit [bold("tap: listening on 0.0.0.0:#{listen_port} -> #{up_host}:#{up_port}"),
      dim("     #{c('C->S', 36)} = client to server, #{c('S->C', 35)} = server to client"), '']

server = TCPServer.new('0.0.0.0', listen_port)
loop do
  client = server.accept
  Thread.new(client) do |sock|
    upstream = TCPSocket.new(up_host, up_port.to_i)
    emit ['', bold("=== new TCP connection from #{sock.peeraddr[3]}:#{sock.peeraddr[1]} ===")]

    pump = lambda do |src, dst, parser|
      Thread.new do
        while (chunk = src.readpartial(65_536))
          parser << chunk     # decode a copy
          dst.write(chunk)    # forward untouched
        end
      rescue EOFError, IOError, Errno::ECONNRESET
        # connection closed
      ensure
        [src, dst].each { |s| s.close rescue nil }
      end
    end

    a = pump.call(sock, upstream, H2Parser.new('C->S', 36))
    b = pump.call(upstream, sock, H2Parser.new('S->C', 35))
    [a, b].each(&:join)
    emit [dim('=== connection closed ===')]
  rescue StandardError => e
    emit ["tap error: #{e.class}: #{e.message}"]
  end
end
