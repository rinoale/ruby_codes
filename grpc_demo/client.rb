#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gRPC client. By default it talks to the tap on 50052, which forwards to the
# real server on 50051 while printing every byte in both directions.
#
#   ruby client.rb                 # through the tap  (localhost:50052)
#   ruby client.rb localhost:50051 # straight to the server
#
$LOAD_PATH.unshift(__dir__)
require 'grpc'
require 'greeter_services_pb'

target = ARGV[0] || 'localhost:50052'
stub = Greeter::Greeter::Stub.new(target, :this_channel_is_insecure)

# --- What the client will actually put on the wire -------------------------
req = Greeter::HelloRequest.new(name: 'kevin', times: 3)
bytes = Greeter::HelloRequest.encode(req)
puts "[client] request message   : #{req.inspect}"
puts "[client] protobuf bytes    : #{bytes.unpack1('H*')}  (#{bytes.bytesize} bytes)"
puts "[client] gRPC frame on wire: 00 #{format('%08x', bytes.bytesize)} #{bytes.unpack1('H*')}"
puts "[client]                     ^compressed-flag  ^big-endian length  ^message"
puts

# --- Unary call ------------------------------------------------------------
puts '=== SayHello (unary) ==='
reply = stub.say_hello(req, metadata: { 'x-demo-header' => 'hi-from-client' })
puts "[client] reply            : #{reply.inspect}"
puts "[client] reply bytes      : #{Greeter::HelloReply.encode(reply).unpack1('H*')}"
puts

# --- Server-streaming call -------------------------------------------------
puts '=== CountDown (server streaming) ==='
stub.count_down(req).each do |r|
  puts "[client] <- #{r.message.inspect} (count=#{r.count})"
end
puts

# --- An error, so you can see grpc-status != 0 in the trailers -------------
puts '=== Deliberate error (unknown method) ==='
begin
  GRPC::ClientStub
    .new(target, :this_channel_is_insecure)
    .request_response('/greeter.Greeter/NoSuchMethod', req,
                      Greeter::HelloRequest.method(:encode),
                      Greeter::HelloReply.method(:decode))
rescue GRPC::BadStatus => e
  puts "[client] status=#{e.code} (#{e.class}) details=#{e.details.inspect}"
end
