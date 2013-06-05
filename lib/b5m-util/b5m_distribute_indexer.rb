require_relative "b5m_m"
require 'sf1-util/sf1_distribute_wait'
require 'sf1-util/sf1_driver_or_nginx'
class B5mDistributeIndexer
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


  def opip

    return @param['opip'] unless @param['opip'].nil?

    @param['ip']
  end
  def cip

    return @param['cip'] unless @param['cip'].nil?

    @param['ip']
  end

  def use_driver?
    return false unless @param['use_driver'].nil?
    return @param['use_driver']
  end

  def b5mo_scd_path(m)
    path = @param['dest_collection_path']
    path+="/#{schema}o"
    if m.mode>0
      path+="/scd/rebuild_scd"
    else
      path+="/scd/index"
    end

    path
  end
  def b5mp_scd_path(m)
    path = @param['dest_collection_path']
    path+="/#{schema}p"
    if m.mode>0
      path+="/scd/rebuild_scd"
    else
      path+="/scd/index"
    end

    path
  end
  def b5mc_scd_path(m)
    path = @param['dest_collection_path']
    path+="/#{schema}c"
    if m.cmode>0
      path+="/scd/rebuild_scd"
    else
      path+="/scd/index"
    end

    path
  end

  def submit_scd(m)
    cmd_list = []
    if m.mode>=0
      opip.each do |ip|
        if m.mode>0
          cmd_list << "ssh #{user}@#{ip} 'rm -rf #{b5mo_scd_path(m)}/*.SCD'"
          cmd_list << "ssh #{user}@#{ip} 'rm -rf #{b5mp_scd_path(m)}/*.SCD'"
        end
        unless m.b5mo_scd_list.empty?
          cmd_list << "scp -C #{m.b5mo}/*.SCD #{user}@#{ip}:#{b5mo_scd_path(m)}/"
        end
        unless m.b5mp_scd_list.empty?
          cmd_list << "scp -C #{m.b5mp}/*.SCD #{user}@#{ip}:#{b5mp_scd_path(m)}/"
        end
      end
    end
    if m.cmode>=0
      cip.each do |ip|
        if m.cmode>0
          cmd_list << "ssh #{user}@#{ip} 'rm -rf #{b5mc_scd_path(m)}/*.SCD'"
        end
        unless m.b5mc_scd_list.empty?
          cmd_list << "scp -C #{m.b5mc}/*.SCD #{user}@#{ip}:#{b5mc_scd_path(m)}/"
        end
      end
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
          conn = Sf1DriverOrNginx.new(opcmdip, port)
        else
          conn = Sf1DriverOrNginx.new(opcmdip, port, "sf1r")
        end
        clear = false
        clear = true if m.mode>0
        sf1 = Sf1DistributeWait.new(conn, [o_collection_name, p_collection_name], clear)
        sf1.index_finish(3600*24*7)
      end
      threads << t
    end
    if m.cmode>=0
      t = Thread.new do
        conn = nil
        if use_driver?
          conn = Sf1DriverOrNginx.new(ccmdip, port)
        else
          conn = Sf1DriverOrNginx.new(ccmdip, port, "sf1r")
        end
        clear = false
        clear = true if m.cmode>0
        sf1 = Sf1DistributeWait.new(conn, [c_collection_name], clear)
        sf1.index_finish(3600*24*7)
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

