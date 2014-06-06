

class B5mCollection
  attr_accessor :schema, :name, :fs, :source_path, :target_path
  def initialize(s, n, f, sp=nil, tp=nil)
    @schema = s
    @name = n
    @fs = f
    @source_path = sp
    @target_path = tp
  end
end

