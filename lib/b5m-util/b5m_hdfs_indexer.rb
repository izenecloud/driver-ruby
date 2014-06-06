require_relative "b5m_m"
require_relative 'b5m_indexer'
require_relative 'b5m_indexer_module'
require_relative 'b5m_collection'
require_relative 'b5m_fs'
require_relative 'hdfs_helper'
require 'sf1-util/sf1_driver_or_nginx'
class B5mHdfsIndexer
  include B5mIndexerModule
  attr_accessor :schema, :ignoreo, :ignorep
  def initialize(param)
    @param = param
    @ignoreo = false
    if !@param['ignoreo'].nil? and @param['ignoreo']
      @ignoreo = true
    end
    #STDERR.puts "ignoreo: #{@ignoreo}"
    @ignorep = false
    if !@param['ignorep'].nil? and @param['ignorep']
      @ignorep = true
    end
    @fs = B5mFs::HDFS
    #STDERR.puts "ignorep: #{@ignorep}"
  end

  def get_collections_detail(suffixes=[])
    if suffixes.empty?
      collection = B5mCollection.new(schema, collection_name, @fs)
      return [collection]
    end
    collections = []
    suffixes.each do |s|
      key = "ignore#{s}"
      if !@param[key].nil? and @param[key]
        STDERR.puts key
        next
      end
      collection = B5mCollection.new(schema, "#{collection_name}#{s}", @fs)
      collections << collection
    end
    return collections
  end

  def get_collections
    if schema=="__other"
      return get_collections_detail([])
    elsif schema=="b5m"
      return get_collections_detail(['o','p','a','c'])
    elsif schema=="tuan"
      return get_collections_detail(['m','a'])
    else
      return get_collections_detail(['o','p'])
    end
  end

  def method_missing(m, *args, &block)
    key = m.to_s
    pv = @param[key]
    return pv unless pv.nil?
    if key.end_with? 'collection_name'
      name = key[0, key.length-'_collection_name'.length]
      if collection_name=="tuan"
        name = "m" if name=="o"
        name = "a" if name=="p"
      end
      return "#{collection_name}#{name}"
    end
  end

  def collection_name
    return schema if @param['collection_name'].nil?
    return @param['collection_name']
  end

  def ip_list
    ip = @param['ip']
    if ip.is_a? Array
      return ip
    else
      return [ip]
    end
  end


  def use_driver?
    return false unless @param['use_driver'].nil?
    return @param['use_driver']
  end

  def b5mo_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{o_collection_name}"

    path
  end
  def b5mp_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{p_collection_name}"

    path
  end
  def b5mc_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{c_collection_name}"

    path
  end
  def scd_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}"

    path
  end

  def b5mo_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{o_collection_name}"

    path
  end
  def b5mp_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{p_collection_name}"

    path
  end
  def b5mc_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{c_collection_name}"

    path
  end
  def scd_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}"

    path
  end

  def source_path(collection, m)
    if collection.schema=="__other"
      return m.scd
    elsif collection.schema=="tuan"
      if collection.name.end_with? 'm'
        return m.b5mo
      elsif collection.name.end_with? 'a'
        return m.b5mp
      end
    else
      suffix = collection.name[-1]
      func = "b5m#{suffix}"
      return m.send(func)
    end
  end

  def target_path(collection, m)
    if collection.schema=="__other"
      return "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}"
    else
      return "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{collection_name}/#{m.name}/#{collection.name}"
    end
  end

  def get_mode(collection, m)
    if collection.schema=="__other"
      return m.mode
    else
      suffix = collection.name[-1]
      if suffix=='c'
        return m.cmode
      else
        return m.mode
      end
    end
  end

  def index_one(m, opt={})
    scd_only = opt[:scd_only]
    scd_only = false if scd_only.nil?
    collections = get_collections
    collections.each do |collection|
      sp = source_path(collection, m)
      tp = target_path(collection, m)
      mode = get_mode(collection, m)
      STDERR.puts "stm : #{sp}, #{tp}, #{mode}"
      scd_list = ScdParser::get_scd_list(sp)
      if scd_list.empty? or mode<0
        STDERR.puts "#{collection.name} scd list empty or mode<0, ignore"
        next
      end
      if sp!=tp
        STDERR.puts "need to copy scd"
        sleep 10.0
        cmd_list = []
        cmd_list << "rm -rf #{tp}"
        cmd_list << "mkdir -p #{tp}"
        cmd_list << "cp #{sp}/*.SCD #{tp}/"
        cmd_list.each do |cmd|
          STDERR.puts cmd
          system(cmd)
          raise "cmd fail" unless $?.success?
        end
      end
      itp = tp #index target path
      if collection.fs==B5mFs::HDFS
        itp = HdfsHelper::get_index_path(tp)
      end
      next if scd_only
      ip_list.each do |ip|
        clear = false
        clear = true if mode>0
        STDERR.puts "start to index #{collection.name} with clear=#{clear}, fs=#{B5mFs.to_s(collection.fs)}, path=#{itp}, ip=#{ip}}"
        #next
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        indexer = B5mIndexer.new(conn, collection.name, clear, itp)
        unless indexer.index
          STDERR.puts "#{collection.name} index on #{ip} fail"
        end
      end
    end
    #if schema=="__other"
    #  index_path = scd_scd_path(m)
    #  if m.scd!=index_path
    #    STDERR.puts "need to copy scd to hdfs"
    #    sleep 10.0
    #    cmd_list = []
    #    cmd_list << "rm -rf #{index_path}"
    #    cmd_list << "mkdir -p #{index_path}"
    #    cmd_list << "cp #{m.scd}/*.SCD #{index_path}/"
    #    cmd_list.each do |cmd|
    #      STDERR.puts cmd
    #      system(cmd)
    #      raise "cmd fail" unless $?.success?
    #    end
    #  end
    #  return if scd_only
    #  ip_list.each do |ip|
    #    conn = nil
    #    if use_driver?
    #      conn = Sf1DriverOrNginx.new(ip, port)
    #    else
    #      conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
    #    end
    #    clear = false
    #    clear = true if m.mode>0
    #    indexer = B5mIndexer.new(conn, collection_name, clear, scd_index_path(m))
    #    unless indexer.index
    #      raise "#{collection_name} index on #{ip} fail"
    #    end
    #  end
    #  return
    #end
    #b5mo_scd_list = ScdParser.get_scd_list(b5mo_scd_path(m))
    #b5mp_scd_list = ScdParser.get_scd_list(b5mp_scd_path(m))
    #b5mc_scd_list = ScdParser.get_scd_list(b5mc_scd_path(m))
    #scd_only = opt[:scd_only]
    #scd_only = false if scd_only.nil?
    #return if scd_only
    #STDERR.puts "o_collection_name #{o_collection_name}"
    #STDERR.puts "p_collection_name #{p_collection_name}"
    #STDERR.puts "b5mo scd path #{b5mo_scd_path(m)}"
    #STDERR.puts "b5mp scd path #{b5mp_scd_path(m)}"
    #if m.mode>=0
    #  ip_list.each do |ip|
    #    conn = nil
    #    if use_driver?
    #      conn = Sf1DriverOrNginx.new(ip, port)
    #    else
    #      conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
    #    end
    #    clear = false
    #    clear = true if m.mode>0
    #    if !b5mo_scd_list.empty? and !@ignoreo
    #      oindexer = B5mIndexer.new(conn, o_collection_name, clear, b5mo_index_path(m))
    #      unless oindexer.index
    #        raise "#{o_collection_name} index on #{ip} fail"
    #      end
    #    end 
    #    if !b5mp_scd_list.empty? and !@ignorep
    #      pindexer = B5mIndexer.new(conn, p_collection_name, clear, b5mp_index_path(m))
    #      unless pindexer.index
    #        raise "#{p_collection_name} index on #{ip} fail"
    #      end
    #    end
    #  end
    #end
    #if m.cmode>=0
    #  ip_list.each do |ip|
    #    conn = nil
    #    if use_driver?
    #      conn = Sf1DriverOrNginx.new(ip, port)
    #    else
    #      conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
    #    end
    #    clear = false
    #    clear = true if m.cmode>0
    #    cindexer = B5mIndexer.new(conn, c_collection_name, clear, b5mc_index_path(m))
    #    unless cindexer.index
    #      raise "#{c_collection_name} index on #{ip} fail"
    #    end

    #  end
    #end
  end

  #def index_multi(m_list, opt={})
  #  rebuild = nil
  #  m_list.each do |m|
  #    if m.mode>0 or m.cmode>0
  #      rebuild = m
  #    end
  #  end
  #  unless rebuild.nil?
  #    puts "processing rebuild #{rebuild}"
  #    sleep 20.0
  #    index_one(rebuild, opt)
  #  end
  #  inc_m_list = m_list.clone
  #  unless rebuild.nil?
  #    inc_m_list.clear
  #    m_list.each do |m|
  #      if m.time>rebuild.time
  #        inc_m_list << m
  #      end
  #    end
  #  end
  #  return if inc_m_list.empty?
  #  lastm = inc_m_list.last
  #  scd_only = opt[:scd_only]
  #  scd_only = false if scd_only.nil?
  #  return if scd_only
  #  ip_list.each do |ip|
  #    conn = nil
  #    if use_driver?
  #      conn = Sf1DriverOrNginx.new(ip, port)
  #    else
  #      conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
  #    end
  #    unless @ignoreo
  #      oindexer = B5mIndexer.new(conn, o_collection_name, false, b5mo_index_path(lastm))
  #      unless oindexer.index
  #        raise "#{o_collection_name} index on #{ip} fail"
  #      end
  #    end
  #    unless @ignorep
  #      pindexer = B5mIndexer.new(conn, p_collection_name, false, b5mp_index_path(lastm))
  #      unless pindexer.index
  #        raise "#{p_collection_name} index on #{ip} fail"
  #      end
  #    end
  #  end
  #end
end


