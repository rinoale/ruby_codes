#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gRPC server. Listens on 50051 (plaintext HTTP/2, no TLS, so the tap can read it).
#
#   ruby server.rb

$LOAD_PATH.unshift(__dir__)
require 'grpc'
require 'greeter_services_pb'

class GreeterServer < Greeter::Greeter::Service
  # Unary handler: return one message.
  def say_hello(req, call)
    warn "[server] SayHello name=#{req.name.inspect} times=#{req.times}"
    warn "[server]   request metadata: #{call.metadata.reject { |k, _| k.start_with?('grpc-') }}"

    # Metadata you set here is sent as the *initial* HEADERS frame of the response.
    call.output_metadata['x-served-by'] = 'ruby-greeter'

    Greeter::HelloReply.new(message: "Hello, #{req.name}!", count: 1)
  end

  # Server-streaming handler: an Enumerator, one DATA frame per yielded message.
  def count_down(req, _call)
    warn "[server] CountDown name=#{req.name.inspect} times=#{req.times}"
    Enumerator.new do |y|
      req.times.downto(1) do |i|
        y << Greeter::HelloReply.new(message: "#{req.name}: #{i}", count: i)
        sleep 0.2
      end
      y << Greeter::HelloReply.new(message: "#{req.name}: liftoff", count: 0)
    end
  end
end

server = GRPC::RpcServer.new
port = server.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
server.handle(GreeterServer)
warn "[server] listening on 0.0.0.0:#{port} (plaintext h2c)"
server.run_till_terminated_or_interrupted(['INT', 'TERM'])
