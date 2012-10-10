require "sf1-driver"

class Sf1Wait
        
  def initialize(collections, conn)
    @collections = collections
    @conn = conn
    @status_before_list = []
    @collections.each do |collection|
      request = {:collection => collection}
      response = conn.call("status/index", request)
      status_before_list << response
    end
    @command = 'index'
  end

  def wait_finish(seconds)
    @collections.each_with_index do |collection, i|
      status_before = status_before_list[i]
      wait(seconds, 10) do |elapsed|
        if true
          ready = :continue
          status_after = cobra.api.status! :collection => collection
          if status_after[@command]["counter"] != status_before[@command]["counter"] and
              status_after[@command]["status"] == "idle"
            # success if modification time has changed
            if status_after[@command]["last_modified"] > status_before[@command]["last_modified"]
              puts "#{collection} #{@command} finished in #{elapsed} seconds" if ENV["VERBOSE"]
              ready = true
            else
              puts "#{collection} #{@command} failed"
              ready = false
            end
          end
        else
          ready = false
        end

        ready
      end
    end
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
end


