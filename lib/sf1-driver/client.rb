#---
# Author::  Ian Yang
# Created:: <2010-07-13 15:17:46>
#+++
#
# Client of Sf1 Driver

require "sf1-driver/helper"
require "socket"

class Sf1Driver
  # Manage the connection to Sf1 Driver
  class Client
    include Helper

    # Host of the SF1 Driver Server (BA or proxy)
    attr_accessor :host

    # Port of the SF1 Driver Server (BA or Proxy)
    attr_accessor :port

    # Default constructor options
    DEFAULT_OPTIONS = {
      :host => "127.0.0.1",
      :port => 18181,
    }

    # Create the driver client.
    #
    # Parameters:
    #
    # [host] Host of the SF1 Driver Server
    # [port] Port of the SF1 Driver Server
    #
    # Also see default values in DEFAULT_OPTIONS
    def initialize(options = {})
      options = DEFAULT_OPTIONS.merge options
      @host = options[:host]
      @port = options[:port].to_i
      @sock = nil
    end

    # Connect to SF1 Driver Server
    def connect
      @sock = TCPSocket.new(@host, @port)
    rescue Errno::ECONNREFUSED
      raise Errno::ECONNREFUSED, "Unable to connect to #{server_name}"
    end

    def connected?
      !!@sock
    end

    def close
      if @sock
        @sock.close rescue nil
        @sock = nil
      end
    end

    def reconnect
      close
      connect
    end

    # Send a request and get the response
    def call(sequence, request_data)
      send_request(sequence, request_data) do
        get_response do |sequence, response_data|
          yield sequence, response_data if block_given?
        end
      end
    end

    # Send a request to SF1
    #
    # Parameters
    # [sequence] sequence number of the request, it must be a unsigned 32bit integer.
    # [request_data] Request data
    def send_request(sequence, request_data)
      bytes = [sequence, num_bytes(request_data), request_data].pack("NNa*")
      ensure_connected do
        @sock.write bytes
        yield if block_given?
      end
    end

    # Get a response from SF1
    #
    # Returns nil or [sequence, response_data].
    #
    # [sequence] Sequence number of the corresponding request or 0 for server error.
    # [response_data] Response data
    def get_response
      return unless @sock

      form_header_buffer = @sock.read(header_size)
      unless form_header_buffer and form_header_buffer.length == header_size
        close
        raise Errno::ECONNRESET, "Connection to #{server_name} lost"
      end

      response_sequence, response_size = form_header_buffer.unpack('NN')
      response_data = ""
      if response_size > 0
        response_data = @sock.read(response_size)
        unless response_data and response_data.length == response_size
          close
          raise Errno::ECONNRESET, "Connection to #{server_name} lost"
        end
      end

      yield response_sequence, response_data if block_given?
      [response_sequence, response_data]
    end

  protected
    def ensure_connected(autoconnect = true)
      connect if autoconnect && !connected?

      begin
        yield
      rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::ETIMEDOUT
        if autoconnect && reconnect
          yield
        else
          raise Errno::ECONNRESET
        end
      end
    end

    def server_name
      "Sf1 Driver Server on #{host}:#{port}"
    end
  end
end
