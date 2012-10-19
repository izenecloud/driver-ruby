require 'b5m-util/b5m_config.rb'
require 'b5m-util/b5m_sf1_instance.rb'

class B5mTask

  attr_accessor :mdb_instance, :mode
  attr_reader :config, :instance_list

  Sf1Instance = Struct.new(:user, :ip, :port)


  def initialize(file)
    @mode = 0
    @config = B5mConfig.new(file)
    @instance_list = []
    @config.sf1_instances.each do |si|
      instance = B5mSf1Instance.new(si, @config.name, @config.no_comment?)
      @instance_list << instance
    end
    #if mode>0
      #@instance_list = @instance_list[0,1]
      #@instance_list[0].ip = "localhost"
    #end
    @mdb_instance = nil
  end


  def work_dir

    config.path_of('work_dir')
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
    threads = []
    instance_list.each do |instance|
      t = Thread.new do
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
          mdb_instance_post_path = []
          mdb_instance_post.each do |mdb_post|
            mdb_instance_post_path << File.join(mdb, mdb_post)
          end
          if doindex
            instance.index(mdb_instance_post_path, mode)
          else
            instance.scd_post(mdb_instance_post_path)
          end
          instance.set_scd_time(end_scd_time)
        end
      end
      threads << t
    end
    threads.each {|t| t.join}
  end


end
