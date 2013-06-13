module B5mIndexerModule
  
  def index(m, opt={})
    if m.is_a? Array
      if instance_methods(false).include?(:index_multi)
        index_multi(m, opt)
      else
        m.each do |im|
          index_one(m, opt)
        end
      end
    else
      index_one(m, opt)
    end
  end
end
