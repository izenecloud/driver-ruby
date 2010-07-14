# See Sf1Driver::Connection

require "sf1-driver"

class Sf1Driver
  class Connection < Sf1Driver
    def open(*args, &block)
      Connection.new(*args, &block)
    end

    def initialize(*args, &block)
      puts "Warning: Sf1Driver::Connection is deprecated, use Sf1Driver instead"
      super(*args, &block)
    end
  end
end
