require 'sf1-driver'
require 'sf1-util/scd_parser'
require 'sf1-util/sf1_wait'
require 'sf1-util/sf1_logger'

B5mCollection = Struct.new(:coll_name, :str)

class B5mSf1Instance
  include Sf1Logger
  @@test = false
  attr_reader :name, :collections
  attr_accessor :test
  def initialize(params, name, nocomment = false)
    @params = params
    @name = name
    @collections = [ B5mCollection.new("#{name}p", "b5mp"), 
      B5mCollection.new("#{name}o", "b5mo") ]
    unless nocomment
      @collections << B5mCollection.new("#{name}c", "b5mc")
    end
  end

  def self.test

    @@test
  end

  def self.test=(param)
    @@test = param
  end

  def to_s

    "#{ip}:#{server_ips}"
  end

  def port
    if @params['port'].nil?
      return default_port
    else
      return @params['port']
    end
  end

  def local?

    return (ip=="localhost" or ip=="127.0.0.1")
  end

  def b5m_server?
    return (ip=="b5m_server")
  end

  def scd_post(m_list, index=-1)
    if local?
      local_scd_post(m_list,index)
    elsif b5m_server?
      b5m_server_scd_post(m_list,index)
    else
      remote_scd_post(m_list, ip,index)
    end
  end

  def index(m_list)
    normal_index(m_list, ip, port)
  end

  def get_scd_time()
    puts "ip: #{@params['ip']}"
    if b5m_server?
      puts "bs get scd time"
      return b5m_server_get_scd_time
    else
      puts "single get scd time"
      return sf1_get_scd_time(ip, port)
    end
  end

  def set_scd_time(time_str)
    if b5m_server?
      b5m_server_set_scd_time(time_str)
    else
      sf1_set_scd_time(ip, port, time_str)
    end
  end

  def method_missing(m, *args, &block)
    @params[m.to_s]
  end

  private
  def scd_time_collection

    "#{name}p"
  end

  def scd_time_key

    "b5m_scd_time"
  end

  def sf1_set_scd_time(ip, port, time_str)
    puts "setting scd time on #{ip} : #{time_str}"
    conn = Sf1Driver.new(ip, port)
    request = {:collection => scd_time_collection, :key => scd_time_key, :value => time_str}
    begin
      response = conn.call("collection/set_kv", request)
    rescue
      puts "set scd time #{time_str} on #{ip} fail"
    end
  end

  def b5m_server_set_scd_time(time_str)
    ips = b5m_server_ips
    ips.each do |ip|
      sf1_set_scd_time(ip, default_port, time_str)
    end
  end

  def sf1_get_scd_time(ip, port)
    puts "getting scd time #{ip}"
    conn = Sf1Driver.new(ip, port)
    request = {:collection => scd_time_collection, :key => scd_time_key}
    begin
      response = conn.call("collection/get_kv", request)
      r = response["value"]
      puts "got scd time #{r}"
      return r
    rescue
      puts "get scd time on #{ip} fail"
      return nil
    end
  end

  def b5m_server_get_scd_time
    ips = b5m_server_ips
    time_list = []
    ips.each do |ip|
      time_list << sf1_get_scd_time(ip, default_port)
    end
    min_time = time_list.first
    has_nil = false
    time_list.each do |time|
      if time.nil?
        has_nil = true
        break
      elsif time<min_time
        min_time = time
      end
    end
    if has_nil
      return nil
    end

    min_time
  end

  def local_scd_post(m_list, index=-1)
    #delete scd/index/*SCD firstly on local post
    collections = @collections
    if index>=0
      collections = []
      collection = @collections[index]
      unless collection.nil?
        collections = [collection]
      end
    end
    collections.each do |collection|
      dest = @params["#{collection.str}_scd"]
      next if dest.nil?
      dest.each do |d|
        FileUtils.mkdir_p(d) unless File.exist?(d)
        cmd = "rm -rf #{d}/*.SCD"
        puts cmd
        system(cmd)
      end
    end
    m_list.each do |m|
      collections.each do |collection|
        str = collection.str
        dest = @params["#{str}_scd"]
        next if dest.nil?
        scd_path = File.join(m.path, str)
        scd_list = ScdParser.get_scd_list(scd_path)
        next if scd_list.empty?
        dest.each do |d|
          FileUtils.mkdir_p(d) unless File.exist?(d)
          scd_list.each do |scd|
            puts "copying #{scd} to #{d}"
            FileUtils.cp_r(scd, d)
          end
        end
      end
    end
  end

  def default_port

    18181
  end

  def switch_seconds

    if @@test
      return 2
    end

    120
  end

  def b5m_server_ips

    #if @@test
      #return ['localhost', '127.0.0.1']
    #end

    server_ips
  end

  def default_indicator_file

    "/opt/cdn-image/upload/keepalived"
  end

  def server_indicator_file
    if @params['indicator_file'].nil?
      return default_indicator_file
    else
      return @params['indicator_file']
    end
  end

  def b5m_server_scd_post(m_list, index=-1)
    ips = b5m_server_ips
    ips.each do |ip|
      remote_scd_post(m_list, ip, index)
    end
  end

  def remote_scd_post(m_list, ip, index=-1)
    collections = @collections
    if index>=0
      collection = @collections[index]
      unless collection.nil?
        collections = [collection]
      end
    end
    m_list.each do |m|
      collections.each do |collection|
        str = collection.str
        scd_path = File.join(m.path, str)
        scd_list = ScdParser.get_scd_list(scd_path)
        puts "#{scd_path} scd size #{scd_list.size}"
        next if scd_list.empty?
        scd_list.each do |scd|
          cname = collection.coll_name
          cmd = "curl -s -T #{scd} ftp://#{ip}/ --user #{cname}:#{cname}"
          puts cmd
          system(cmd)
          unless $?.success?
            raise "curl #{scd} on #{ip} with #{cname} error"
          end
        end
      end
    end
  end

  def normal_index(m_list, ip, port)
    conn = Sf1Driver.new(ip, port)
    last_m = m_list.last
    @collections.each_with_index do |collection, i|
      coll = collection.coll_name
      collections = [coll]
      clear = false

      if i<=1 and last_m.mode>0 #reindex for o,p
        clear = true
      end
      if i==2 #for comment
        if last_m.cmode>0
          clear = true
        elsif last_m.cmode<0
          puts "#{coll} mode<0, ignore"
          next
        end
      end
      puts "indexing #{coll} with clear=#{clear}, index #{i}"
      sf1 = Sf1Wait.new(conn, collections, clear)
      begin
        sf1.index_finish(3600*24*7) do 
          unless b5m_server?
            scd_post(m_list,i)
          else
            remote_scd_post(m_list, ip,i)
          end
        end
      rescue Exception => e
        puts "instance index error #{e}"
      end
    end
  end

  def b5m_server_index(m_list, mode)
    if mode==0
      ips = b5m_server_ips
      ips.each do |ip|
        normal_index(m_list, mode, ip, default_port)
      end
    else
      b5m_server_reindex(m_list)
    end
  end

  def b5m_server_reindex(m_list)
    ips = b5m_server_ips
    ifile = server_indicator_file
    map = {"b5m-d1" => ips[0], "b5m-d2" => ips[1]}
    switch_map = {"b5m-d1" => "b5m-d2", "b5m-d2" => "b5m-d1"}
    puts "loading #{ifile}"
    flag = `cat #{ifile}`
    flag.strip!
    puts "current flag #{flag}"
    unless map.has_key?(flag)
      puts "#{flag} not allowed"
      return
    end
    sflag = switch_map[flag]
    ip = map[sflag]
    puts "so work on #{sflag} #{ip}"
    normal_index(m_list, 1, ip, default_port)
    #now do switch
    puts "output #{sflag}"
    system("echo #{sflag} > #{ifile}")
    sm = switch_seconds
    puts "sleep #{sm} minutes"
    sleep(sm) #sleep 2 minutes
    ip = map[flag]
    puts "now work on #{flag} #{ip}"
    normal_index(m_list, 1, ip, default_port)
  end

end

