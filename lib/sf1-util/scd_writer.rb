
class ScdWriter
  
  def initialize(dir, type = 'I')
    sleep(1.0/100.0)
    time = Time::now
    filename = time.strftime("B-00-%Y%m%d%H%M-%S%3N-#{type}-C.SCD")
    f = dir+"/"+filename
    @o_file = File.new(f, "w")
  end
  
  def append(doc)
    docid = doc[:DOCID]
    docid = doc['DOCID'] if docid.nil?
    return if docid.nil?
    @o_file.puts "<DOCID>#{docid}"
    doc.each do |key, value|
      if key.to_s=="DOCID"
        next
      end
      @o_file.puts "<#{key}>#{value}"
    end
#     @o_file.flush
  end
  
  def close
    @o_file.close
  end
  
end
  
