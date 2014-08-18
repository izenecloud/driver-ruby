
class B5mOmapper
  def initialize(data)
    @map = {}
    File.open(data, 'r').each_line do |line|
      line.strip!
      vec = line.split(':')
      next if vec.size!=2
      category = vec[1]
      v = vec[0].split(',')
      next if v.size!=2
      v[0].strip!
      v[1].strip!
      @map[v] = category
    end
    STDERR.puts "#{data} omapper size #{@map.size}"
  end

  def get_category(doc)
    source = doc['Source']
    original = doc['OriginalCategory']
    return nil if source.nil? or original.nil?
    return nil if source.empty? or original.empty?
    source.strip!
    original.strip!
    key = [source, original]
    value = @map[key]
    return value
  end
end

