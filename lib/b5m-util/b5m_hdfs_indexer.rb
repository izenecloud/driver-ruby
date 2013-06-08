require_relative "b5m_m"
require_relative 'b5m_indexer'
require 'sf1-util/sf1_driver_or_nginx'
class B5mHdfsIndexer
  attr_accessor :schema
  def initialize(param)
    @param = param
  end

  def method_missing(m, *args, &block)
    key = m.to_s
    if key.end_with? 'collection_name'
      name = key[0, key.length-'_collection_name'.length]
      return "#{schema}#{name}"
    else
      return @param[m.to_s]
    end
  end


  def use_driver?
    return false unless @param['use_driver'].nil?
    return @param['use_driver']
  end

  def b5mo_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}o"

    path
  end
  def b5mp_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}p"

    path
  end
  def b5mc_scd_path(m)
    path = "#{@param['hdfs_mnt']}/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}c"

    path
  end

  def b5mo_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}o"

    path
  end
  def b5mp_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}p"

    path
  end
  def b5mc_index_path(m)
    path = "/#{@param['hdfs_prefix']}/#{schema}/#{m.name}/#{schema}c"

    path
  end

  def submit_scd(m)
    cmd_list = []
    if m.mode>=0
      cmd_list << "rm -rf #{b5mo_scd_path(m)}"
      cmd_list << "mkdir -p #{b5mo_scd_path(m)}"
      cmd_list << "cp #{m.b5mo}/*.SCD #{b5mo_scd_path(m)}/"
      cmd_list << "rm -rf #{b5mp_scd_path(m)}"
      cmd_list << "mkdir -p #{b5mp_scd_path(m)}"
      cmd_list << "cp #{m.b5mp}/*.SCD #{b5mp_scd_path(m)}/"
    end
    if m.cmode>=0
      cmd_list << "rm -rf #{b5mc_scd_path(m)}"
      cmd_list << "mkdir -p #{b5mc_scd_path(m)}"
      cmd_list << "cp #{m.b5mc}/*.SCD #{b5mc_scd_path(m)}/"
    end
    cmd_list.each do |cmd|
      STDERR.puts cmd
      system(cmd)
      raise "cmd fail" unless $?.success?
    end
  end

  def submit_index(m)
    threads = []
    if m.mode>=0
      #request = {:collection => o_collection_name}
      #response = @conn.call("commands/index", request)
      #request = {:collection => p_collection_name}
      #response = @conn.call("commands/index", request)
      t = Thread.new do
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        clear = false
        clear = true if m.mode>0
        oindexer = B5mIndexer.new(conn, o_collection_name, clear, b5mo_index_path(m))
        oindexer.index
        pindexer = B5mIndexer.new(conn, p_collection_name, clear, b5mp_index_path(m))
        pindexer.index
      end
      threads << t
    end
    if m.cmode>=0
      t = Thread.new do
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ip, port)
        else
          conn = Sf1DriverOrNginx.new(ip, port, "sf1r")
        end
        clear = false
        clear = true if m.cmode>0
        cindexer = B5mIndexer.new(conn, c_collection_name, clear, b5mc_index_path(m))
        cindexer.index
      end
      threads << t
    end
    threads.each do |t|
      t.join
    end
  end

  def index(m)
    submit_scd(m)
    submit_index(m)
  end
end


