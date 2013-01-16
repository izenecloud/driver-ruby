
class CategoryTask
  ATT = 1 #attribute indexing approach
  COM = 2 #complete match approach
  SIM = 3 #similarity based approach
  TIC = 4 #for ticket approach

  attr_reader :type, :category, :cid, :info, :valid, :regex

  def initialize(line)
    str = line
    @type = ATT
    @category = ""
    @cid = ""
    @info = {}
    @valid = true
    @regex = true
    if str.start_with?("#")
      str = str[1..-1]
      @valid = false
    end
    a = str.split(',')
    @category = a[0]
    @cid = a[1]
    if a.size>=4 and a[2]=="COMPLETE"
      @type = COM
      @info['name'] = a[3]
    elsif a.size>=3 and a[2]=="SIMILARITY"
      @type = SIM
    elsif a.size>=3 and a[2]=="TICKET"
      @type = TIC
    elsif a.size>=3 and a[2]=="DISABLE"
      @info['disable'] = true
    end

    if @category=="OPPOSITE" or @category=="OPPOSITEALL"
      @regex = false
    end
  end

  def to_s
    r = "#{@category},#{@cid}"
    if @type==ATT
      unless @info['disable'].nil?
        r += ",DISABLE"
      end
    elsif @type==COM
      r += ",COMPLETE,#{@info['name']}"
    elsif @type==TIC
      r += ",TICKET"
    else
      r += ",SIMILARITY"
    end

    r
  end

end

class B5mHelper

  def self.matcher
    File.join( File.dirname(__FILE__), "lib", "cpp", "b5m_matcher")
  end

  def self.config_file
    File.join( File.dirname(__FILE__), "config", "matcher.yml")
  end

  def self.run_matcher(args=nil,config=nil)
    cfile = config_file
    cfile = config unless config.nil?
    unless File.exists?(cfile)
      abort "config file #{cfile} not exists"
    end
    cmd = "#{matcher} --config #{cfile}"
    cmd += " #{args}" unless args.nil?
    system(cmd)
  end
end

class MdbStatus
  def initialize(mdb)
    @mdb = mdb
    unless File.directory? @mdb
      raise "#{@mdb} dir not exists"
    end
  end

  def file
    File.join(@mdb, "status")
  end

  def status
    unless File.file?(file)
      return "finished"
    else
      str = "finished"
      File.open(file, 'r') do |f|
        str = f.readline().strip
      end
      return str
    end
  end

  def status=(str)
    File.open(file, 'w') do |f|
      f.write(str)
    end
  end
end

def self.get_b5m_logger
  if $logger.nil?
    $logger = Logger.new(STDERR)
  end
  
  $logger
end

