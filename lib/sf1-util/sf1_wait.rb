require "sf1-driver"
require 'sf1-util/sf1_logger'

class Sf1Wait
  include Sf1Logger
        
  def initialize(conn, collections, clear = false)
    @conn = conn
    @collections = collections
    @clear = clear
    #@command = 'index'
  end

  def index_finish(seconds)
    if @clear
      @collections.each do |coll|
        request = {:collection => coll, :clear => true} #stop and clear
        #stop collection
        puts "stopping and clearing #{coll}"
        response = @conn.call("collection/stop_collection", request)
        puts response

      end
      @collections.each do |coll|
        request = {:collection => coll}
        #stop collection
        #restart collection
        puts "starting #{coll}"
        response = @conn.call("collection/start_collection", request)
        puts response
      end
    else
      #do connectioin test
      @collections.each do |coll|
        request = {:message => "incremental index test connection"}
        puts "incremental index test conn on #{coll}"
        response = @conn.call("test/echo", request)
        puts response
      end
    end
    yield if block_given?
    status_before_list = []
    @collections.each do |collection|
      request = {:collection => collection}
      response = @conn.call("status/index", request)
      status_before_list << response
    end
    @collections.each do |collection|
      request = {:collection => collection}
      response = @conn.call("commands/index", request)
      puts response
    end
    #if @clear
      #@collections.each do |collection|
        #request = {:collection => collection}
        #response = @conn.call("collection/rebuild_from_scd", request)
      #end
    #else
    #end
    #@collections.each_with_index do |collection, i|
      #status_before = status_before_list[i]
      #wait(seconds, 10) do |elapsed|
        #if true
          #ready = :continue
          #status_after = @conn.call("status/index", {:collection => collection})
          #if status_after["index"]["counter"] != status_before["index"]["counter"] and
              #status_after["index"]["status"] == "idle"
            ## success if modification time has changed
            #if status_after["index"]["last_modified"] > status_before["index"]["last_modified"]
              #puts "#{collection} index finished in #{elapsed} seconds"
              #ready = true
            #else
              #puts "#{collection} index failed"
              #ready = false
            #end
          #else
            #puts "#{collection} indexing..."
          #end
        #else
          #ready = false
        #end

        #ready
      #end
    #end
  end

  private

  def wait(timeout, interval = 1)
    elapsed = 0
    result = false
    loop do
      sleep interval
      elapsed += interval

      start = Time.now
      result = yield elapsed
      elapsed += (Time.now - start).to_i
      break unless result.nil? or result.is_a?(Symbol)

      result = false
      break if timeout and elapsed >= timeout

      interval += 1
    end

    result
  end
end


