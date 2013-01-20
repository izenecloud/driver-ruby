require 'date'

class B5mInputScd
  include Comparable
  attr_reader :path, :time
  def initialize(path)
    @path = path
    dt = DateTime.strptime(File.basename(@path), "%Y%m%d%H%M%S")
    @time = dt.to_time
  end

  def <=>(o)
    return time<=>o.time
  end

  def self.get_all(dir, done_file_name, time=Time.at(0))
    unless File.directory? dir
      return []
    end
    list = []
    Dir.foreach(dir) do |m|
      next unless m =~ /\d{14}/
      mm = File.join(dir, m)
      next unless File.directory?(mm)
      done_file = File.join(mm, done_file_name)
      next unless File.exists? done_file
      t = DateTime.strptime(m, "%Y%m%d%H%M%S").to_time
      list << B5mInputScd.new(mm) if t>time
    end

    list.sort!
  end
end

