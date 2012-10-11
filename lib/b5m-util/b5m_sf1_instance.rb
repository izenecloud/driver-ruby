require 'sf1-driver'
require 'sf1-util/sf1_wait'

class B5mSf1Instance
  @@test = false
  attr_reader :name, :collections
  attr_accessor :test
  def initialize(params, name="b5m")
    @params = params
    @name = name
    @collections = ["#{name}p", "#{name}o"]
    unless @params[:b5mc_scd].nil?
      @collections << "#{name}c"
    end
  end

  def self.test

    @@test
  end

  def self.test=(param)
    @@test = param
  end

  def to_s

    ip
  end

  def inspect

    ip
  end

  def local?

    return (ip=="localhost" or ip=="127.0.0.1")
  end

  def b5m_server?
    return (ip=="b5m_server")
  end

  def scd_post(mdb_instance)
    if local?
      local_scd_post(mdb_instance)
    elsif b5m_server?
      b5m_server_scd_post(mdb_instance)
    else
      remote_scd_post(mdb_instance, ip)
    end
  end

  def index(mode)
    if b5m_server?
      b5m_server_index(mode)
    else
      normal_index(mode, ip, port)
    end
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

  def local_scd_post(mdb_instance)
    strs = ['b5mo', 'b5mp', 'b5mc']
    strs.each do |str|
      dest = @params["#{str}_scd"]
      next if dest.nil?
      scd_path = File.join(mdb_instance, str)
      scd_list = ScdParser.get_scd_list(scd_path)
      next if scd_list.empty?
      dest.each do |d|
        FileUtils.mkdir_p(d) unless File.exist?(d)
        cmd = "rm -rf #{d}/*.SCD"
        system(cmd)
        scd_list.each do |scd|
          puts "copying #{scd}"
          FileUtils.cp_r(scd, d)
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

    if @@test
      return ['localhost', '127.0.0.1']
    end

    ['10.10.1.106', '10.10.1.107']
  end

  def b5m_server_scd_post(mdb_instance)
    ips = b5m_server_ips
    ips.each do |ip|
      remote_scd_post(mdb_instance, ip)
    end
  end

  def remote_scd_post(mdb_instance, ip)
    strs = ['b5mo', 'b5mp', 'b5mc']
    strs.each_with_index do |str, i|
      scd_path = File.join(mdb_instance, str)
      scd_list = ScdParser.get_scd_list(scd_path)
      next if scd_list.empty?
      scd_list.each do |scd|
        cname = collections[i]
        system("curl -s -T #{scd} ftp://#{ip}/ --user #{cname}:#{cname}")
      end
    end
  end
  
  def normal_index(mode, ip, port)
    conn = Sf1Driver.new(ip, port)
    clear = false

    if mode>0 #reindex
      clear = true
    end
    sf1 = Sf1Wait.new(conn, @collections, clear)
    sf1.index_finish(3600*24)
  end

  def b5m_server_index(mode)
    if mode==0
      ips = b5m_server_ips
      ips.each do |ip|
        normal_index(mode, ip, default_port)
      end
    else
      b5m_server_reindex
    end
  end

  def b5m_server_reindex
    ips = b5m_server_ips
    ifile = "/opt/cdn-image/upload/keepalived"
    map = {"b5m-d1" => ips[0], "b5m-d2" => ips[1]}
    switch_map = {"b5m-d1" => "b5m-d2", "b5m-d2" => "b5m-d1"}
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
    normal_index(1, ip, default_port)
    #now do switch
    puts "output #{sflag}"
    system("echo #{sflag} > #{ifile}")
    sm = switch_seconds
    puts "sleep #{sm} minutes"
    sleep(sm) #sleep 2 minutes
    ip = map[flag]
    puts "now work on #{flag} #{ip}"
    normal_index(1, ip, default_port)
  end

end

