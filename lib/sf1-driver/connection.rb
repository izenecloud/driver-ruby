# See Sf1Driver::Connection

require "sf1-driver/helper"
require "sf1-driver/client"

class Sf1Driver

  class ServerError < RuntimeError; end

  class Connection
    # Max sequence number. It is also the upper limit of the number of requests
    # in a batch request.
    #
    # max(int32) - 1
    MAX_SEQUENCE = (1 << 31) - 2

    # Tells the sequence number of next request
    attr_reader :sequence

    # save errors for batch sending
    attr_reader :sever_errors

    # Alias of new
    def self.open(host, port, opts = {}, &block) #:yields: self
      Connection.new(host, port, opts, &block)
    end

    # Connect server listening on host:port
    #
    # Parameters:
    #
    # [host] IP of the host BA is running on.
    # [port] Port BA is listening.
    # [opts] Options
    #        [format] Select underlying writer and reader, now only "json"
    #                 is supported, and it is also the default format.
    def initialize(host, port, opts = {}) #:yields: self
      opts = {:format => "json"}.merge opts

      use_format(opts[:format])

      @client = Client.new(:host => host, :port => port)

      # 0 is reserved by server
      @sequence = 1

      if block_given?
        yield self
        close
      end
    end

    # Closes the connection
    def close
      @client.close
    end

    # Chooses data format. Now only "json" is supported, and it is also the default format.
    def use_format(format)
      reader_file = "sf1-driver/readers/#{format}-reader"
      writer_file = "sf1-driver/writers/#{format}-writer"
      require reader_file
      require writer_file

      eval "extend #{Helper.camel(format)}Reader"
      eval "extend #{Helper.camel(format)}Writer"
    end

    def server_errors #:nodoc:
      @server_errors ||= []
    end

    # Send request.
    #
    # Parameters:
    #
    # [+uri+] a string with format "/controller/action". If action is "index",
    #         it can be omitted
    # [+request+] just a hash
    #
    # Return:
    #
    # * When used in non batch mode, this function is synchronous. The request
    #   is sent to function and wait for the response. After then, the response
    #   is used as the return value of this function.
    #
    # * When send is used in batch block, the request is sent after the block is
    #   closed. The allocated sequence number is returned immediately. Responses
    #   are returned in function block.
    #
    # Examples:
    #
    #     request = {
    #       :collection => "ChnWiki",
    #       :resource => {
    #         :DOCID => 1
    #         :title => "SF1v5 Driver Howto"
    #       }
    #     }
    #     connection.send("documents/create", request)
    #
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
    #
    # Parameters:
    # [requests] An array. Every element is an array with two elements, uri and request object.
    #
    # Return:
    # 
    # Response array is returned. It has the same size with requests and in the same sequence
    # of their corresponding request. Because of server error, some responses may be nil. In such
    # situation, check server_errors.
    #
    # Examples:
    #
    #     requests = []
    #     requests << ["documents/create", {
    #                    :collection => "ChnWiki",
    #                    :resource => {
    #                      :DOCID => 1,
    #                      :title => "Sf1v5 Driver Howto"
    #                    }
    #                  }]
    #     requests << ["documents/create", {
    #                    :collection => "ChnWiki",
    #                    :resource => {
    #                      :DOCID => 2,
    #                      :title => "Programming Ruby"
    #                    }
    #                  }]
    #     
    #     send_batch(requests)
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

    # Stores request in array. Requests will be sent in batch after the batch
    # block is closed.
    def add_batch_request(uri, request)
      raise "Too many requests in batch" if @batch_requests.length > MAX_SEQUENCE
      request_sequence = @sequence + @batch_requests.length
      if request_sequence > MAX_SEQUENCE
        request_sequence -= MAX_SEQUENCE
      end
      @batch_requests << [uri, request]
      request_sequence
    end

    # Write request to server
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

    # Read request to server
    def read
      response = read_raw
      if response
        response_sequence, payload = response
        return [response_sequence, reader_deserialize(payload)]
        # return [response_sequence, payload]
      end
    end

    # Write raw request to server. It is in the format specified in use_format. 
    def write_raw(request)
      @client.send_request(@sequence, request)
    end

    # Read raw response from server. It is in the format specified in use_format.
    def read_raw
      @client.get_response
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
