#---
# Author::  Ian Yang
# Created:: <2010-07-13 16:35:33>
#+++
#
# Mock of Sf1 Driver Server

require "socket"
require "spec"
require "sf1-driver/helper"

module Sf1DriverMock
  include Sf1Driver::Helper

  DEFAULT_RESPONSE = '{"header":{"success":true}}'
  DEFAULT_MOCK_PORT = 18283

  def start_sf1_mock(port = DEFAULT_MOCK_PORT)
    catch (:done) do
      TCPServer.open("127.0.0.1", port) do |server|
        session = server.accept
        while header_buffer = session.read(header_size)
          sequence, request_size = header_buffer.unpack("NN")
          request_data = session.read(request_size)
          break unless request_data
          response_data = nil
          if block_given?
            response_data = yield sequence, request_data
          end
          response_data ||= DEFAULT_RESPONSE
          bytes = [sequence, num_bytes(response_data), response_data].pack("NNa*")
          session.write bytes
        end
      end
    end
  end

  # Forks a process and starts a new mock Sf1 Driver server
  def sf1_mock(mock = nil, port = DEFAULT_MOCK_PORT)
    begin
      server_thread = Thread.new do
        begin
          if mock
            start_sf1_mock(port) do |sequence, request_data|
              mock.on_request(sequence, request_data)
            end
          else
            start_sf1_mock(port)
          end
        rescue RuntimeError => e
          raise e if e.message != "interrupt"
        end
      end

      sleep 1

      yield

    ensure
      if server_thread
        server_thread.raise("interrupt")
        server_thread.join
      end
    end
  end
end
