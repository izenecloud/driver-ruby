require 'yaml'
require 'tmpdir'

class B5mConfig
  attr_reader :file, :config, :id, :name, :schema, :matcher_ip, :matcher_port, :coll_name, :collection_name, :o_collection_name, :p_collection_name, :a_collection_name, :c_collection_name, :omapper, :thread_num, :buffer_size, :sorter_bin, :imc, :auto_rebuild, :omapper, :complete_interval
  def initialize(file)
    @file = File.expand_path(file)
    root = YAML.load_file(@file)
    @config = root["config"]
    @config = root if @config.nil?
    @id = File.basename(@file, ".yml")
    @name = @config['name']
    @schema = "b5m"
    unless @config['schema'].nil?
      @schema = @config['schema']
    end
    @matcher_ip = "0.0.0.0"
    @matcher_port = 18190
    unless @config['matcher_port'].nil?
      @matcher_port = @config['matcher_port']
    end
    @omapper = @config['omapper']
    @thread_num = nil
    unless @config['thread_num'].nil?
      @thread_num = @config['thread_num'].to_i
    end
    @buffer_size = nil
    unless @config['buffer_size'].nil?
      @buffer_size = @config['buffer_size']
    end
    @sorter_bin = nil
    unless @config['sorter_bin'].nil?
      @sorter_bin = @config['sorter_bin']
    end
    @imc = 0
    unless @config['imc'].nil?
      @imc = @config['imc'].to_i
    end
    @auto_rebuild = @config['auto_rebuild']
    @omapper = @config['omapper']
    if @config['path_of']['work_dir'].nil?
      @config['path_of']['work_dir'] = File.join(File.dirname(@file), "work_dir")
    end
    @complete_interval = @config['complete_interval']
    if @complete_interval.nil?
      @complete_interval = 24*3600
    end
    @coll_name = @schema
    indexer = @config['indexer']
    unless indexer.nil?
      collection_name = indexer['collection_name']
      unless collection_name.nil?
        @coll_name = collection_name
      end
    end
    @collection_name = @coll_name
    @o_collection_name = "#{@collection_name}o"
    @p_collection_name = "#{@collection_name}p"
    @a_collection_name = "#{@collection_name}a"
    @c_collection_name = "#{@collection_name}c"
    if @schema=="tuan"
      @o_collection_name = "#{@collection_name}m"
      @p_collection_name = "#{@collection_name}a"
    end
      
    unless indexer.nil?
      @o_collection_name = indexer['o_collection_name'] unless indexer['o_collection_name'].nil?
      @p_collection_name = indexer['p_collection_name'] unless indexer['p_collection_name'].nil?
    end
    #@b5mo_name = "#{name}o"
    #@b5mp_name = "#{name}p"
    #@b5mc_name = "#{name}c"
    Dir.chdir(File.dirname(@file)) do
      @config['path_of'].each_pair do |k,v|
        if v.is_a? Array
          v.each_with_index do |vi, i|
            v[i] = File.expand_path(vi)
          end
        else
          v = File.expand_path(v)
        end
        @config['path_of'][k] = v
      end
      #strs = ['b5mo_scd', 'b5mp_scd', 'b5mc_scd']
      #@config["sf1_instance"].each do |si|
        #strs.each do |str|
          #next if si[str].nil?
          #path = si[str]
          #if path.is_a? Array
            #path.each_with_index do |p,i|
              #path[i] = File.expand_path(p)
            #end
          #else
            #path = [File.expand_path(path)]
          #end
          #si[str] = path
        #end
        #path = si['indicator_file']
        #next if path.nil?
        #si['indicator_file'] = File.expand_path(path)
      #end
    end
  end

  def [](key)

    config[key]
  end

  #def first_ip
    #return nil if @config["sf1_instance"].empty?

    #return @config["sf1_instance"].first["ip"]
  #end

  def path_of(key)

    config['path_of'][key]
  end

  #def no_bdb?
    #r = false
    #unless $config['nobdb'].nil?
      #r = true
    #end

    #r
  #end

  #def no_comment?

    #path_of('comment_scd').nil?
  #end

  def tmp_dir
    return Dir.tmpdir if path_of('tmp_dir').nil?
    return path_of('tmp_dir')
  end

  def monitor?

    return false if @config['monitor'].nil?
    return @config['monitor']
  end
  def use_rtype?

    return false if @config['use_rtype'].nil?
    return @config['use_rtype']
  end

  def monitor_interval
    return 0 if @config['monitor_interval'].nil?
    return @config['monitor_interval']
  end

  def noindex?
    return false if @config['noindex'].nil?
    return @config['noindex']
  end
  def noapply?
    return false if @config['noapply'].nil?
    return @config['noapply']
  end

  def send_mail?
    return true if @config['send_mail'].nil?
    return @config['send_mail']
  end

  def spu_only?
    return false if @config['spu_only'].nil?
    return @config['spu_only']
  end

  def use_psm?
    return false if @config['use_psm'].nil?
    return @config['use_psm']
  end

  def scd_done_name
    return "done" if @config['scd_done_name'].nil?
    return @config['scd_done_name']
  end

  def save(file)
    obj = {:config => @config}
    File.open(file, "w") do |f|
      f.puts obj.to_yaml
    end
  end

  #def sf1_instances

    #config['sf1_instance']
  #end

end
