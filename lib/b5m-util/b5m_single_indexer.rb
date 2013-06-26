require_relative "b5m_m"
require_relative 'b5m_indexer_module'
require 'sf1-util/sf1_wait'
class B5mSingleIndexer
  include B5mIndexerModule
  attr_accessor :schema
  def initialize(param)
    @param = param
  end

  def method_missing(m, *args, &block)
    key = m.to_s
    if key.end_with? 'collection_name'
      name = key[0, key.length-'_collection_name'.length]
      if schema=="tuan"
        name = "m" if name=="o"
        name = "a" if name=="p"
      end
      return "#{schema}#{name}"
    else
      return @param[m.to_s]
    end
  end

  def get_scd_path(mode, coll)
    if schema=="tuan"
      coll = "m" if coll=="o"
      coll = "a" if coll=="p"
    end
    path = @param['dest_collection_path']
    path+="/#{schema}#{coll}"
    if !@param['sf1r_collection_path'].nil? and @param['sf1r_collection_path']
      if mode>0
        path+="/scd/rebuild_scd"
      else
        path+="/scd/index"
      end
    end

    return path
  end


  def opip

    return @param['opip'] unless @param['opip'].nil?

    @param['ip']
  end
  def cip

    return @param['cip'] unless @param['cip'].nil?

    @param['ip']
  end

  def use_driver?

    true
  end

  #def user

    #@param['user']
  #end

  def local?
    ip=="localhost" or ip=="127.0.0.1"
  end

  def index_one(m, opt={})
    o_scd_path = get_scd_path(m.mode, "o")
    p_scd_path = get_scd_path(m.mode, "p")
    c_scd_path = get_scd_path(m.cmode, "c")
    cmd_list = []
    if m.mode>=0
      if local?
        if m.mode>0
          cmd_list << "rm -rf #{o_scd_path}/*.SCD"
          cmd_list << "rm -rf #{p_scd_path}/*.SCD"
        end
        unless m.b5mo_scd_list.empty?
          cmd_list << "cp #{m.b5mo}/*.SCD #{o_scd_path}/"
        end
        unless m.b5mp_scd_list.empty?
          cmd_list << "cp #{m.b5mp}/*.SCD #{p_scd_path}/"
        end
      else
        if m.mode>0
          cmd_list << "ssh #{user}@#{opip} 'rm -rf #{o_scd_path}/.SCD'"
          cmd_list << "ssh #{user}@#{opip} 'rm -rf #{p_scd_path}/.SCD'"
        end
        unless m.b5mo_scd_list.empty?
          cmd_list << "scp -C #{m.b5mo}/*.SCD #{user}@#{opip}:#{o_scd_path}/"
        end
        unless m.b5mp_scd_list.empty?
          cmd_list << "scp -C #{m.b5mp}/*.SCD #{user}@#{opip}:#{p_scd_path}/"
        end
      end
    end
    if m.cmode>=0
      if local?
        if m.cmode>0
          cmd_list << "rm -rf #{c_scd_path}/*.SCD"
        end
        unless m.b5mc_scd_list.empty?
          cmd_list << "cp #{m.b5mc}/*.SCD #{c_scd_path}/"
        end
      else
        if m.cmode>0
          cmd_list << "ssh #{user}@#{cip} 'rm -rf #{c_scd_path}/.SCD'"
        end
        unless m.b5mc_scd_list.empty?
          cmd_list << "scp -C #{m.b5mc}/*.SCD #{user}@#{cip}:#{c_scd_path}/"
        end
      end
    end
    cmd_list.each do |cmd|
      STDERR.puts cmd
      system(cmd)
      raise "cmd fail" unless $?.success?
    end
    scd_only = opt[:scd_only]
    scd_only = false if scd_only.nil?
    return if scd_only
    threads = []
    if use_driver?
      if m.mode>=0
        #request = {:collection => o_collection_name}
        #response = @conn.call("commands/index", request)
        #request = {:collection => p_collection_name}
        #response = @conn.call("commands/index", request)
        t = Thread.new do
          conn = Sf1Driver.new(opip, port)
          clear = false
          clear = true if m.mode>0
          sf1 = Sf1Wait.new(conn, [o_collection_name, p_collection_name], clear)
          sf1.index_finish(3600*24*7)
        end
        threads << t
      end
      if m.cmode>=0
        #request = {:collection => c_collection_name}
        #response = @conn.call("commands/index", request)
        t = Thread.new do
          conn = Sf1Driver.new(cip, port)
          clear = false
          clear = true if m.cmode>0
          sf1 = Sf1Wait.new(conn, [c_collection_name], clear)
          sf1.index_finish(3600*24*7)
        end
        threads << t
      end
    else
      #use http
    end
    threads.each do |t|
      t.join
    end
  end
end
