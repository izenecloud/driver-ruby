require 'date'
require 'sf1-util/scd_parser'

class B5mInputScd
  include Comparable
  attr_reader :path, :time, :name
  def initialize(path)
    @path = path
    @name = File.basename(@path)
    dt = DateTime.strptime(@name, "%Y%m%d%H%M%S")
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
      scd_list = ScdParser.get_scd_list(mm)
      next if scd_list.empty?
      t = DateTime.strptime(m, "%Y%m%d%H%M%S").to_time
      list << B5mInputScd.new(mm) if t>time
    end

    list.sort!
  end

  def self.get_time(scd_dir)
    name = File.basename(scd_dir)
    return nil unless mname =~ /\d{14}/
    t = DateTime.strptime(name, "%Y%m%d%H%M%S").to_time
    return t
  end
end

