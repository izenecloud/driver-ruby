require 'sf1-driver'
require 'sf1-util/scd_parser'
require 'sf1-util/sf1_wait'
require 'sf1-util/sf1_logger'

B5mCollection = Struct.new(:coll_name, :str)

class B5mIndexer
  def initialize(params, prefix="b5m")
    @params = params
    @prefix = prefix
    @collections = [ B5mCollection.new("#{name}p", "b5mp"), 
      B5mCollection.new("#{name}o", "b5mo") ]
    unless nocomment
      @collections << B5mCollection.new("#{name}c", "b5mc")
    end
  end

  def index(m_list)
    normal_index(m_list, ip, port)
  end

end

