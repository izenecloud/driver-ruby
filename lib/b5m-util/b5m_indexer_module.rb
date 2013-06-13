module B5mIndexerModule
  
  def index(m, opt={})
    if m.is_a? Array
      if self.respond_to?('index_multi')
        self.index_multi(m, opt)
      else
        m.each do |im|
          self.index_one(im, opt)
        end
      end
    else
      self.index_one(m, opt)
    end
  end
end
