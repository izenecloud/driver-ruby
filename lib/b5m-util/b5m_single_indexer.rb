require_relative "b5m_m"
require 'sf1-util/sf1_wait'
class B5mSingleIndexer
  attr_accessor :schema
  def initialize(param)
    @param = param
  end

  def method_missing(m, *args, &block)
    key = m.to_s
    if key.end_with? '_scd_path'
      name = key[0,key.length-'_scd_path'.length]
      path = @param['dest_collection_path']
      path+="/#{schema}#{name}"
      if @param['sf1r_collection_path']
        path+="/scd/index"
      end
      return path
    elsif key.end_with? 'collection_name'
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

    true
  end

  #def user

    #@param['user']
  #end

  def local?
    ip=="localhost" or ip=="127.0.0.1"
  end

  def submit_scd(m)
    cmd_list = []
    if m.mode>=0
      if local?
        if m.mode>0
          cmd_list << "rm -rf #{o_scd_path}/*.SCD"
          cmd_list << "rm -rf #{p_scd_path}/*.SCD"
        end
        cmd_list << "cp #{m.b5mo}/*.SCD #{o_scd_path}/"
        cmd_list << "cp #{m.b5mp}/*.SCD #{p_scd_path}/"
      else
        cmd_list << "scp -C #{m.b5mo}/*.SCD #{user}@#{opip}:#{o_scd_path}/"
        cmd_list << "scp -C #{m.b5mp}/*.SCD #{user}@#{opip}:#{p_scd_path}/"
      end
    end
    if m.cmode>=0
      if local?
        if m.cmode>0
          cmd_list << "rm -rf #{c_scd_path}/*.SCD"
        end
        cmd_list << "cp #{m.b5mc}/*.SCD #{c_scd_path}/"
      else
        cmd_list << "scp -C #{m.b5mc}/*.SCD #{user}@#{cip}:#{c_scd_path}/"
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
    #threads.each do |t|
      #t.join
    #end
  end

  def index(m)
    submit_scd(m)
    submit_index(m)
  end
end
