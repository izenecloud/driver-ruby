require 'b5m-util/b5m_sf1_instance.rb'

class B5mTask

  attr_accessor :mdb_instance, :mode
  attr_reader :file, :config, :instance_list, :name, :b5mo_name, :b5mp_name, :b5mc_name

  Sf1Instance = Struct.new(:user, :ip, :port)


  def initialize(file)
    @mode = 0
    @file = File.expand_path(file)
    @config = YAML.load_file(@file)["config"]
    @name = File.basename(@file, ".yml")
    @name = @config['name'] unless @config['name'].nil?
    @b5mo_name = "#{name}o"
    @b5mp_name = "#{name}p"
    @b5mc_name = "#{name}c"
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
      strs = ['b5mo_scd', 'b5mp_scd', 'b5mc_scd']
      @config["sf1_instance"].each do |si|
        strs.each do |str|
          next if si[str].nil?
          path = si[str]
          if path.is_a? Array
            path.each_with_index do |p,i|
              path[i] = File.expand_path(p)
            end
          else
            path = [File.expand_path(path)]
          end
          si[str] = path
        end
      end
    end
    @instance_list = []
    @config["sf1_instance"].each do |si|
      instance = B5mSf1Instance.new(si, name)
      @instance_list << instance
    end
    #if mode>0
      #@instance_list = @instance_list[0,1]
      #@instance_list[0].ip = "localhost"
    #end
    @mdb_instance = nil
  end

  def no_bdb?
    r = false
    unless $config['nobdb'].nil?
      r = true
    end

    r
  end

  def path_of(key)

    @config['path_of'][key]
  end

  def work_dir

    path_of('work_dir')
  end

  def db

    File.join(work_dir, "db")
  end

  def mdb
    
    File.join(db, "mdb")
  end

  def mdb_instance_list
    list = []
    Dir.foreach(mdb) do |m|
      next unless m =~ /\d{14}/
      mm = File.join(mdb, m)
      next unless File.directory?(mm)
      list << m
    end

    list.sort!
  end

  def dispatch(opt={})
    use_scd_time = opt[:use_scd_time] || false
    doindex = opt[:do_index] || true

    mi_list = mdb_instance_list
    instance_list.each do |instance|
      puts "dispatching to #{instance}"
      mdb_instance_post = []
      if !use_scd_time and !mdb_instance.nil?
        mdb_instance_post << mdb_instance
      else
        start_scd_time = instance.get_scd_time
        if start_scd_time.nil?
          start_scd_time = mi_list.first
        else
          start_scd_time = (start_scd_time.to_i+1).to_s
        end
        mi_list.each do |mi|
          if mi>=start_scd_time
            mdb_instance_post << mi
          end
        end
      end
      if mdb_instance_post.empty?
        puts "#{instance} has no more mdb instance to be processed"
      else
        puts "#{instance} has #{mdb_instance_post.size} mdb instances to be processed"
        end_scd_time = mdb_instance_post.last
        mdb_instance_post.each do |mdb_post|
          instance.scd_post(File.join(mdb, mdb_post))
          if doindex
            instance.index(mode)
          end
        end
        instance.set_scd_time(end_scd_time)
      end
    end
  end


end
