require 'sf1-driver'
require 'sf1-util/sf1_logger'


class B5mIndexer
  include Sf1Logger
  def initialize(conn, collection, clear, scd_path=nil)
    @conn = conn
    @collection = collection
    @clear = clear
    @scd_path = scd_path
  end

  def index
    if @clear
      @collections.each do |coll|
        request = {:collection => coll}
        unless @scd_path.nil?
          request[:index_scd_path] = @scd_path
        end
        STDERR.puts "rebuilding #{request}"
        response = @conn.call("collection/rebuild_from_scd", request)
        return false if response.nil?
        STDERR.puts response
      end
    else
      @collections.each do |coll|
        request = {:collection => coll}
        unless @scd_path.nil?
          request[:index_scd_path] = @scd_path
        end
        STDERR.puts "indexing #{request}"
        response = @conn.call("commands/index", request)
        return false if response.nil?
        STDERR.puts response
      end
    end
  end

end

