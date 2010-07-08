require 'socket'
require 'timeout'
require 'stringio'

require 'forwardable'

module Sf1Driver

  class ServerError < RuntimeError; end

  # TODO: auto detect request type
  class Connection
    class << self
      def num_bytes(str)
        s = StringIO.new(str)
        s.seek(0, IO::SEEK_END)
        s.tell
      end

      def camel(str)
        str.split("-").map{|s| s.capitalize}.join
      end
    end
    
    INT_SIZE = Connection::num_bytes([1].pack('N'))

    # max(int32) - 1
    MAX_SEQUENCE = (1 << 31) - 2

    extend Forwardable

    def_delegators :@socket, :close, :close_read, :close_write

    # tells the sequence number of next request
    attr_reader :sequence

    # save errors for batch sending
    attr_reader :sever_errors

    def self.open(ip, port, opts = {}, &block)
      Connection.new(ip, port, opts, &block)
    end

    # Connect server listening on ip:port
    #
    # supported opts:
    #
    # - timeout: timeout in seconds when connecting server.
    # - format: select underlying writer and reader, now we have following formats:
    #           - json
    def initialize(ip, port, opts = {})
      opts = {:timeout => 5, :format => "json"}.merge opts

      use_format(opts[:format])

      Timeout::timeout(opts[:timeout].to_i) do
        @socket = TCPSocket.new(ip, port);
      end

      # 0 is reserved by server
      @sequence = 1

      if block_given?
        yield self
        close
      end
    end

    def use_format(format)
      reader_file = "sf1-driver/readers/#{format}-reader"
      writer_file = "sf1-driver/writers/#{format}-writer"
      require reader_file
      require writer_file

      eval "extend #{Connection.camel(format)}Reader"
      eval "extend #{Connection.camel(format)}Writer"
    end

    def server_errors
      @server_errors ||= []
    end

    # Send request and wait for response.
    #
    # In batch block, Returns the sequence number of current request. Requests are
    # send after block is closed, then all responses are returned. See batch for details.
    #
    # - uri: a string with format "/controller/action". If action is "index", it can be omitted
    #
    # - request: just a hash
    #
    # e.g.
    # request = {
    #   :collection => "ChnWiki",
    #   :resource => {
    #     :DOCID => 1
    #     :title => "SF1v5 Driver Howto"
    #   }
    # }
    # send("documents/create", request)
    def send(uri, request)
      if @batch_requests
        return add_batch_request(uri, request)
      end

      start_time = Time.now
      remember_sequence = @sequence
      write(uri, request)
      response_sequence, response = read

      raise ServerError, "No response." if response_sequence.nil? || response.nil?
      raise ServerError, "Malformed response." unless response.is_a?Hash

      if response_sequence == 0
        response["errors"] ||= ["Unknown server error."]
        raise ServerError, response["errors"].join("\n")
      end

      if remember_sequence != response_sequence
        raise ServerError, "Unmatch sequence number"
      end

      if request["header"]["check_time"] || request["header"][:check_time]
        response["timers"] ||= {}
        response["timers"]["total_client_time"] = Time.now - start_time
      end

      return response
    end

    # Send multiple requests
    # Requests is an array. Every element is an array with two elements, uri and request object.
    #
    # e.g.
    #
    # requests = []
    # requests << ["documents/create", {
    #                :collection => "ChnWiki",
    #                :resource => {
    #                  :DOCID => 1,
    #                  :title => "Sf1v5 Driver Howto"
    #                }
    #              }]
    # requests << ["documents/create", {
    #                :collection => "ChnWiki",
    #                :resource => {
    #                  :DOCID => 2,
    #                  :title => "Programming Ruby"
    #                }
    #              }]
    #
    # send_batch(requests)
    #
    # The response is also an array. It has the same size with requests and in the same sequence
    # of their corresponding request. Because of server error, some responses may be nil. In such
    # situation, check server_errors
    #
    def send_batch(requests)
      @server_errors = []

      remember_sequence = {}
      timers = []
      requests.each_with_index do |uri_request, index|
        remember_sequence[@sequence] = index
        timers << Time.now
        uri, request = uri_request
        write(uri, request)
      end

      responses = Array.new(requests.length)

      general_error_hash = {}
      begin
        requests.length.times do
          response_sequence, response = read
          if response_sequence.nil? or response.nil?
            general_error_hash["No response for some requests."] = true
          elsif !response.is_a?Hash
            general_error_hash["Some responses are malformed."] = true
          elsif response_sequence == 0
            if response["errors"]
              if response["errors"].is_a?Array
                @server_errors += response["errors"]
              else
                @server_errors << response["errors"]
              end
            else
              general_error_hash["Unknown server error."]
            end
          elsif !remember_sequence.key? response_sequence
            @server_errors << "Sequence is out of range: #{response_sequence}"
          else
            request_index = remember_sequence[response_sequence]
            request_header = requests[request_index].last["header"]
            if request_header["check_time"] || request_header[:check_time]
              response["timers"] ||= {}
              response["timers"]["total_client_time"] = Time.now - timers[request_index]
            end
            responses[request_index] = response
          end

        end
      rescue => e
        puts e
        puts e.backtrace.join("\n")
        @server_errors << e.to_s
      end
      @server_errors += general_error_hash.keys

      return responses
    end

    # Open a block that send can used to add requests in batch.
    #
    # In batch block, send returns sequence number of that request immediately. Requests are send
    # after the block is closed and responses are returned as the return value of this function.
    #
    # e.g.
    #
    # responses = connection.batch do |c|
    #   c.send "/ChnWiki/commands/create", :resource => {:command => "index"}
    #   c.send "/ChnWiki/commands/create", :resource => {:command => "mining"}
    # end
    #
    def batch
      raise "Cannot nest batch" if @batch_requests
      @batch_requests = []
      begin
        yield self
        responses = send_batch @batch_requests
        @batch_requests = nil
        return responses
      rescue => e
        @batch_requests = nil
        raise e
      end
    end
    private
    def add_batch_request(uri, request)
      request_sequence = @sequence + @batch_requests.length
      if request_sequence > MAX_SEQUENCE
        request_sequence -= MAX_SEQUENCE
      end
      @batch_requests << [uri, request]
      request_sequence
    end

    def write(uri, request)
      controller, action = uri.to_s.split("/").reject{|e| e.nil? || e.empty?}

      if controller.nil?
        raise ArgumentError, "Require controller name."
      end

      header = {}
      header.merge!(request["header"]) if request["header"].is_a? Hash
      header.merge!(request[:header]) if request[:header].is_a? Hash
      request.delete("header")
      request.delete(:header)

      header["controller"] = controller
      header["action"] = action if action

      request["header"] = header

      write_raw(writer_serialize(request))
    end

    def read
      response = read_raw
      if response
        response_sequence, payload = response
        return [response_sequence, reader_deserialize(payload)]
      end
    end

    def write_raw(request)
      bytes = [@sequence, Connection.num_bytes(request), request].pack("NNa*");
      @socket.write bytes
      @sequence += 1
      if @sequence > MAX_SEQUENCE
        @sequence = 1
      end
    end

    def read_raw
      form_header_buffer = @socket.read(INT_SIZE * 2)
      return unless form_header_buffer && form_header_buffer.size == INT_SIZE * 2

      response_sequence, response_size = form_header_buffer.unpack('NN')
      return if response_size == 0

      response_buffer = @socket.read(response_size)
      return unless response_buffer && response_buffer.size == response_size

      return [response_sequence, response_buffer]
    end

  end

  # Helper method to print value
  def self.pp_value(value, offset = 2, level = 0)
    level += 1
    if value.is_a? Array
      print "[\n", " " * offset * level
      first = true
      value.each do |item|
        print ",\n", " " * offset * level unless first
        first = false
        pp_value(item, offset, level)
      end
      level -= 1
      print "\n", " " * offset * level, "]"
    elsif value.is_a? Hash
      print "{\n", " " * offset * level
      first = true
      value.each_pair do |key, item|
        print ",\n", " " * offset * level unless first
        first = false
        print key.inspect, " => "
        pp_value(item, offset, level)
      end
      level -= 1
      print "\n", " " * offset * level, "}"
    else
      print value
    end
    if level == 0
      puts
    end
  end

end
