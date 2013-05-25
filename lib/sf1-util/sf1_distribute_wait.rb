require "sf1-driver"
require 'sf1-util/sf1_logger'

class Sf1DistributeWait
  include Sf1Logger
        
  def initialize(conn, collections, clear = false)
    @conn = conn
    @collections = collections
    @clear = clear
  end

  def index_finish(seconds)
    #status_before_list = []
    #@collections.each do |collection|
      #request = {:collection => collection}
      #response = @conn.call("status/get_distribute_status", request)
      #status_before_list << response
    #end
    if @clear
      @collections.each do |coll|
        request = {:collection => coll}
        puts "rebuilding #{coll}"
        response = @conn.call("collection/rebuild_from_scd", request)
        return false if response.nil?
        puts response
      end
    else
      @collections.each do |coll|
        request = {:collection => coll}
        puts "indexing #{coll}"
        response = @conn.call("commands/index", request)
        return false if response.nil?
        puts response
      end
    end
    sleep 10.0
    @collections.each_with_index do |collection, i|
      wait(seconds, 10) do |elapsed|
        ready = :continue
        if !@clear
          ready = true
        else
          status_after = @conn.call("status/get_distribute_status", {:collection => collection})
          if status_after.nil?
            ready = false
          else
            if !status_after['DistributeStatus'].nil? and !status_after['DistributeStatus']['MemoryStatus'].nil? and !status_after['DistributeStatus']['MemoryStatus']['NodeState'].nil? and status_after['DistributeStatus']['MemoryStatus']['NodeState'].to_i==3
              ready = true
            else
              puts "#{collection} indexing..."
            end
          end
        end

        ready
      end
    end
  end

  private

  def puts(str)

    Sf1Logger.puts "#{@conn.host} #{str}"
  end

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



