require 'yaml'
require 'date'

class B5mM
  include Comparable

  attr_reader :name, :path, :mdb, :time

  def initialize(path, name = nil)
    if name.nil?
      @name = File.basename(path)
      @path = path
      @mdb = File.dirname(path)
    else
      @name = name
      @mdb = path
      @path = File.join(path, name)
    end
    raise "#{@name} not a valid m name" unless @name =~ /\d{14}/
    @time = DateTime.strptime(@name, "%Y%m%d%H%M%S").to_time
    @property = {}
    @property_file = File.join(@path, "property")
    @property = YAML.load_file(@property_file) if File.file?(@property_file)
    #@status_file = File.join(@path, "status")
    #@mode_file = File.join(@path, "mode")
    #@cmode_file = File.join(@path, "cmode")
    #if File.file? @status_file
      #@status = IO.readlines(@status_file).first.strip
    #end
    #if File.file? @mode_file
      #@mode = IO.readlines(@mode_file).first.strip.to_i
    #end
    #if File.file? @cmode_file
      #@cmode = IO.readlines(@cmode_file).first.strip.to_i
    #end
  end

  def flush
    File.open(@property_file, 'w') do |f|
      f.write @property.to_yaml
    end
  end

  def method_missing(method_sym, *arguments, &block)
    method = method_sym.to_s
    if method.end_with? "="
      key = method[0, method.length-1]
      @property[key] = arguments.first
    else
      return @property[method]
    end
  end

  def exists?
    File.exists? path
  end

  def broken?
    return true if status.nil?
    return true if status.empty?
    return true if status=="matching"
    return false
  end

  def delete
    if File.exists? path
      FileUtils.rm_rf(path)
    end
  end
  
  def to_s

    path
  end

  def self.get_a_name

    Time.now.strftime("%Y%m%d%H%M%S")
  end

  def <=>(o)
    return name<=>o.name
  end

  def create
    FileUtils.mkdir(path)
    @property['pid'] = Process.pid
    @property['start_time'] = Time.now
  end

  def release

  end

  def b5mo

    File.join(path, "b5mo")
  end

  def b5mp

    File.join(path, "b5mp")
  end

  def b5mc

    File.join(path, "b5mc")
  end

  def odb

    File.join(path, "odb")
  end

  def cdb

    File.join(path, "cdb")
  end

  def bdb

    File.join(path, "bdb")
  end


end

