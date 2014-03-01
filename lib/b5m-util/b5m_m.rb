require 'yaml'
require 'date'

class B5mM
  include Comparable

  attr_reader :name, :path, :mdb, :time, :b5mo, :b5mp, :b5ma, :b5mc, :ou_count, :od_count, :pu_count, :pd_count, :cu_count, :cd_count, :local_b5mo, :local_b5mp, :local_b5ma, :local_b5mc
  attr_accessor :mode, :cmode, :scd, :comment_scd, :knowledge

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
    @mode = @property['mode']
    @cmode = @property['cmode']
    @b5mo = File.join(@path, 'b5mo')
    @b5mp = File.join(@path, 'b5mp')
    @b5ma = File.join(@path, 'b5ma')
    @b5mc = File.join(@path, 'b5mc')
    @local_b5mo = @b5mo
    @local_b5mp = @b5mp
    @local_b5ma = @b5ma
    @local_b5mc = @b5mc
    @ou_count = @property['ou_count'] || 0
    @od_count = @property['od_count'] || 0
    @pu_count = @property['pu_count'] || 0
    @pd_count = @property['pd_count'] || 0
    @cu_count = @property['cu_count'] || 0
    @cd_count = @property['cd_count'] || 0
    config_file = File.join(@path, 'config')
    if File.file? config_file
      bc = B5mConfig.new config_file
      load_config(bc)
    end

  end

  def flush
    @property['mode'] = mode
    @property['cmode'] = cmode
    @property['ou_count'] = @ou_count
    @property['od_count'] = @od_count
    @property['pu_count'] = @pu_count
    @property['pd_count'] = @pd_count
    @property['cu_count'] = @cu_count
    @property['cd_count'] = @cd_count
    File.open(@property_file, 'w') do |f|
      f.write @property.to_yaml
    end
  end

  def count_scd
    unless @b5mo.nil?
      @ou_count, @od_count = ScdParser.get_ud_doc_count(@b5mo)
    end
    unless @b5mp.nil?
      @pu_count, @pd_count = ScdParser.get_ud_doc_count(@b5mp)
    end
    unless @b5mc.nil?
      @cu_count, @cd_count = ScdParser.get_ud_doc_count(@b5mc)
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

  def load_config(config)
    indexer = config.config['indexer']
    return if indexer.nil?
    type = indexer['type']
    return if type.nil?
    return if type!="hdfs"
    prefix = "#{indexer['hdfs_mnt']}/#{indexer['hdfs_prefix']}/#{config.collection_name}/#{@name}"
    if config.schema=="__other"
      @b5mo = prefix
      @b5mp = nil
      @b5ma = nil
      @b5mc = nil
    else
      @b5mo = "/#{prefix}/#{config.o_collection_name}"
      @b5mp = "/#{prefix}/#{config.p_collection_name}"
      @b5ma = "/#{prefix}/#{config.a_collection_name}"
      @b5mc = "/#{prefix}/#{config.c_collection_name}"
    end
  end

  def create(config=nil)
    FileUtils.mkdir(path)
    @property['pid'] = Process.pid
    @property['start_time'] = Time.now
    unless config.nil?
      mconfig = Marshal.load(Marshal.dump(config.config))
      mconfig['path_of']['scd'] = scd
      mconfig['path_of']['knowledge'] = knowledge
      mconfig['mode'] = mode
      mconfig['cmode'] = cmode
      if cmode>=0
        mconfig['path_of']['comment_scd'] = comment_scd
      end
      m_config_file = File.join(@path, "config")
      File.open(m_config_file, 'w') do |f|
        f.puts mconfig.to_yaml
      end
      load_config(config)
    end
  end

  def b5mo_mirror

    File.join(path, "b5mo_mirror")
  end
  def b5mo_block

    File.join(path, "b5mo_block")
  end

  def b5mo_scd_list
    ScdParser.get_scd_list(b5mo)
  end
  def b5mp_scd_list
    ScdParser.get_scd_list(b5mp)
  end
  def b5ma_scd_list
    ScdParser.get_scd_list(b5ma)
  end
  def b5mc_scd_list
    ScdParser.get_scd_list(b5mc)
  end

  def odb

    File.join(path, "odb")
  end

  def cdb

    File.join(path, "cdb")
  end

  def omapper

    File.join(path, "omapper")
  end

  def omapper_data

    File.join(omapper, 'data')
  end

  def bdb

    File.join(path, "bdb")
  end


end

