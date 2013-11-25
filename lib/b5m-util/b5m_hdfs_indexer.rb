require_relative "b5m_m"
require_relative 'b5m_indexer'
require_relative 'b5m_indexer_module'
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
    #STDERR.puts "ignorep: #{@ignorep}"
  end

  def method_missing(m, *args, &block)
    key = m.to_s
    if key.end_with? 'collection_name'
      name = key[0, key.length-'_collection_name'.length]
      if collection_name=="tuan"
        name = "m" if name=="o"
        name = "a" if name=="p"
      end
      return "#{collection_name}#{name}"
    else
      return @param[m.to_s]
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

  def index_one(m, opt={})
    if schema=="__other"
      cmd_list = []
      cmd_list << "rm -rf #{scd_scd_path(m)}"
      cmd_list << "mkdir -p #{scd_scd_path(m)}"
      cmd_list << "cp #{m.scd}/*.SCD #{scd_scd_path(m)}/"
      cmd_list.each do |cmd|
        STDERR.puts cmd
        system(cmd)
        raise "cmd fail" unless $?.success?
      end
      ip_list.each do |ip|
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        clear = false
        clear = true if m.mode>0
        indexer = B5mIndexer.new(conn, collection_name, clear, scd_index_path(m))
        unless indexer.index
          raise "#{collection_name} index on #{ip} fail"
        end
      end
      return
    end
    cmd_list = []
    if m.mode>=0
      if !m.b5mo_scd_list.empty? and !@ignoreo
        cmd_list << "rm -rf #{b5mo_scd_path(m)}"
        cmd_list << "mkdir -p #{b5mo_scd_path(m)}"
        cmd_list << "cp #{m.b5mo}/*.SCD #{b5mo_scd_path(m)}/"
      end
      if !m.b5mp_scd_list.empty? and !@ignorep
        cmd_list << "rm -rf #{b5mp_scd_path(m)}"
        cmd_list << "mkdir -p #{b5mp_scd_path(m)}"
        cmd_list << "cp #{m.b5mp}/*.SCD #{b5mp_scd_path(m)}/"
      end
    end
    if m.cmode>=0
      cmd_list << "rm -rf #{b5mc_scd_path(m)}"
      cmd_list << "mkdir -p #{b5mc_scd_path(m)}"
      cmd_list << "cp #{m.b5mc}/*.SCD #{b5mc_scd_path(m)}/"
    end
    cmd_list.each do |cmd|
      STDERR.puts "ingore cmd #{cmd}"
      #system(cmd)
      #raise "cmd fail" unless $?.success?
    end
    scd_only = opt[:scd_only]
    scd_only = false if scd_only.nil?
    return if scd_only
    STDERR.puts "o_collection_name #{o_collection_name}"
    STDERR.puts "p_collection_name #{p_collection_name}"
    sleep 10.0
    if m.mode>=0
      #request = {:collection => o_collection_name}
      #response = @conn.call("commands/index", request)
      #request = {:collection => p_collection_name}
      #response = @conn.call("commands/index", request)
      ip_list.each do |ip|
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        clear = false
        clear = true if m.mode>0
        if !m.b5mo_scd_list.empty? and !@ignoreo
          oindexer = B5mIndexer.new(conn, o_collection_name, clear, b5mo_index_path(m))
          unless oindexer.index
            raise "#{o_collection_name} index on #{ip} fail"
          end
        end 
        if !m.b5mp_scd_list.empty? and !@ignorep
          pindexer = B5mIndexer.new(conn, p_collection_name, clear, b5mp_index_path(m))
          unless pindexer.index
            raise "#{p_collection_name} index on #{ip} fail"
          end
        end
      end
    end
    if m.cmode>=0
      ip_list.each do |ip|
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        clear = false
        clear = true if m.cmode>0
        cindexer = B5mIndexer.new(conn, c_collection_name, clear, b5mc_index_path(m))
        unless cindexer.index
          raise "#{c_collection_name} index on #{ip} fail"
        end

      end
    end
  end

  def index_multi(m_list, opt={})
    rebuild = nil
    m_list.each do |m|
      if m.mode>0 or m.cmode>0
        rebuild = m
      end
    end
    unless rebuild.nil?
      puts "processing rebuild #{rebuild}"
      sleep 20.0
      index_one(rebuild, opt)
    end
    inc_m_list = m_list.clone
    unless rebuild.nil?
      inc_m_list.clear
      m_list.each do |m|
        if m.time>rebuild.time
          inc_m_list << m
        end
      end
    end
    return if inc_m_list.empty?
    lastm = inc_m_list.last
    cmd_list = []
    unless @ignoreo
      cmd_list << "rm -rf #{b5mo_scd_path(lastm)}"
      cmd_list << "mkdir -p #{b5mo_scd_path(lastm)}"
    end
    unless @ignorep
      cmd_list << "rm -rf #{b5mp_scd_path(lastm)}"
      cmd_list << "mkdir -p #{b5mp_scd_path(lastm)}"
    end
    inc_m_list.each do |m|
      if !m.b5mo_scd_list.empty? and !@ignoreo
        cmd_list << "cp #{m.b5mo}/*.SCD #{b5mo_scd_path(lastm)}/"
      end
      if !m.b5mp_scd_list.empty? and !@ignorep
        cmd_list << "cp #{m.b5mp}/*.SCD #{b5mp_scd_path(lastm)}/"
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
    ip_list.each do |ip|
      conn = nil
      if use_driver?
        conn = Sf1DriverOrNginx.new(ip, port)
      else
        conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
      end
      unless @ignoreo
        oindexer = B5mIndexer.new(conn, o_collection_name, false, b5mo_index_path(lastm))
        unless oindexer.index
          raise "#{o_collection_name} index on #{ip} fail"
        end
      end
      unless @ignorep
        pindexer = B5mIndexer.new(conn, p_collection_name, false, b5mp_index_path(lastm))
        unless pindexer.index
          raise "#{p_collection_name} index on #{ip} fail"
        end
      end
    end
  end
end


