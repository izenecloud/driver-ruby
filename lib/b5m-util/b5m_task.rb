require_relative 'b5m_config.rb'
require_relative 'b5m_sf1_instance.rb'
require_relative 'b5m_m.rb'
require_relative 'b5m_mail.rb'
require 'sf1-util/scd_parser'
require 'sf1-util/sf1_logger'
require 'net/smtp'

class B5mTask
  include Sf1Logger

  attr_accessor :email, :m
  attr_reader :config, :instance_list, :m_list, :last_m, :last_rebuild_m, :last_o_m, :last_c_m, :last_odb, :last_codb, :last_cdb, :scd, :comment_scd, :last_db_m, :last_rebuild_m

  def initialize(config)
    @email = false
    if config.is_a? String
      @config = B5mConfig.new(config)
    else
      @config = config
    end
    @instance_list = []
    @config.sf1_instances.each do |si|
      instance = B5mSf1Instance.new(si, @config.name, @config.no_comment?)
      @instance_list << instance
    end
    unless File.exists? mdb
      FileUtils.mkdir_p(mdb)
    end
    gen
  end

  def gen
    #do broken clean
    return if config.schema=="ticket"
    @m_list = []
    Dir.foreach(mdb) do |m|
      next unless m =~ /\d{14}/
      mm = File.join(mdb, m)
      next unless File.directory?(mm)
      b5m_m = B5mM.new(mm)
      if b5m_m.broken?
        b5m_m.delete
        next
      end
      @m_list << b5m_m
    end
    @m_list.sort!
    #assign last_m, last_odb, last_codb, last_cdb
    @last_m = @m_list.last
    @last_o_m = nil
    @last_odb = nil
    @m_list.reverse_each do |em|
      if em.mode>=0 #do o/p
        @last_o_m = em
        @last_odb = @last_o_m.odb
        break
      end
    end
    @last_codb = nil
    @last_cdb = nil
    @last_c_m = nil
    @m_list.reverse_each do |em|
      if em.cmode>=0 #do b5mc
        @last_codb = em.odb
        @last_cdb = em.cdb
        @last_c_m = em
        break
      end
    end
    @last_db_m = nil
    if @last_o_m.nil?
      @last_db_m = @last_c_m
    elsif @last_c_m.nil?
      @last_db_m = @last_o_m
    else
      @last_db_m = [@last_o_m, @last_c_m].min
    end
    @last_rebuild_m = nil
    @m_list.reverse_each do |em|
      if em.mode>0
        @last_rebuild_m = em
        break
      end
    end
    check_valid
  end

  def check_valid
    check_db_valid @last_odb
    check_db_valid @last_codb
    check_db_valid @last_cdb
  end

  def print_last
    puts "last_m #{@last_m}"
    puts "last_o_m #{@last_o_m}"
    puts "last_c_m #{@last_c_m}"
    puts "last_rebuild_m #{@last_rebuild_m}"
    puts "last_db_m #{@last_db_m}"
    puts "last_odb #{@last_odb}"
    puts "last_codb #{@last_codb}"
    puts "last_cdb #{@last_cdb}"
  end

  def set_last_c_m(m)
    @last_c_m = m
    @last_codb = m.odb
    @last_cdb = m.cdb
    check_valid
  end

  def copy_m(from_m)
    target_m = File.join(mdb, from_m.name)
    if File.exists? target_m
      puts "#{target_m} exists, copy_m failed"
      return false
    end
    puts "copy #{from_m.path} to #{target_m}"
    FileUtils.cp_r from_m.path, target_m
    puts "copied"
    return true
  end

  def m_release
    return if @last_rebuild_m.nil?
    puts "last_rebuild_m #{@last_rebuild_m}"
    gap = @last_rebuild_m
    unless @last_db_m.nil?
      puts "last_db_m #{@last_db_m}"
      gap = [@last_rebuild_m, @last_db_m].min
    end
    puts "m_release gap #{gap}"
    new_m_list = []
    @m_list.each do |m|
      if m<gap
        puts "releasing #{m}"
        m.delete
      else
        new_m_list << m
      end
    end
    @m_list = new_m_list
  end

  def work_dir

    config.path_of('work_dir')
  end

  def knowledge

    File.join(work_dir, "knowledge")
  end

  def bdb

    File.join(knowledge, 'bdb')
  end

  def db

    File.join(work_dir, "db")
  end

  def mdb
    
    File.join(db, "mdb")
  end


  def matcher_start(m)
    @m = m
    if m.exists?
      raise "m #{@m} already exists"
    end
    m.create
    m.status = "matching"
    m.flush
    #then copy related db to the new m
    if m.mode==0 and !last_odb.nil?
      puts "copy #{last_odb} to #{m.odb}"
      FileUtils.cp_r(last_odb, m.odb)
    end
    if m.cmode==0 and !last_cdb.nil?
      puts "copy #{last_cdb} to #{m.cdb}"
      FileUtils.cp_r(last_cdb, m.cdb)
    end
    @scd = config.path_of('scd')
    if m.mode==0 #incremental
      @scd = File.join(@scd, "incremental")
    else
      @scd = File.join(@scd, "rebuild")
    end
    unless File.directory?(@scd)
      @scd = config.path_of('scd')
    end
    @comment_scd = config.path_of('comment_scd')
    puts "offer-scd:#{@scd}"
    puts "comment-scd:#{@comment_scd}"

  end

  def matcher_finish
    @m.status = "matched"
    @m.flush
    gen
  end

  def apply(m, opt={})
    #use_scd_time = opt[:use_scd_time]
    #use_scd_time = false if use_scd_time.nil?
    doindex = opt[:do_index]
    doindex = true if doindex.nil?
    @m = m

    threads = []
    instance_list.each do |instance|
      t = Thread.new do
        puts "applying to #{instance}"
        m_post = [m]
        if m_post.empty?
          puts "#{instance} has no more mdb instance to be processed"
        else
          puts "#{instance} has #{m_post.size} mdb instances to be processed"
          end_scd_time = m_post.last.name
          if doindex
            puts "do index"
            instance.index(m_post)
            #instance.set_scd_time(end_scd_time)
          else
            puts "do scd_post"
            instance.scd_post(m_post)
          end
        end
      end
      threads << t
    end
    threads.each {|t| t.join}
    m.status = "finished"
    m.flush
    m.release
  end

  def send_mail(m)
    return if m.nil?
    return if m.status!="finished" and m.status!="matched"
    subject = "Matcher (#{config.schema})"
    if m.mode>0
      subject += ' Rebuild'
    elsif m.mode==0
      subject += ' Incremental'
    elsif m.cmode>=0
      subject += ' Comment Only'
    end
    subject += " to #{config.first_ip}"
    subject += ' Finish'
    body = "schema #{config.schema}\n"
    body = "working path #{m.path}\n"
    body += "timestamp #{m.name}\n"
    body += "o/p mode #{m.mode}\n"
    body += "c mode #{m.cmode}\n"
    body += "start_time #{m.start_time}\n"
    ou_count, od_count = ScdParser.get_ud_doc_count(m.b5mo)
    pu_count, pd_count = ScdParser.get_ud_doc_count(m.b5mp)
    cu_count, cd_count = ScdParser.get_ud_doc_count(m.b5mc)
    body += "b5mo update doc count #{ou_count}\n"
    body += "b5mo delete doc count #{od_count}\n"
    body += "b5mp update doc count #{pu_count}\n"
    body += "b5mp delete doc count #{pd_count}\n"
    body += "b5mc update doc count #{cu_count}\n"
    body += "b5mc delete doc count #{cd_count}\n"


    begin

      B5mMail.send({:host => 'localhost', 
                   :to => ['dri@b5m.com', 'ds@b5m.com'],
                   :from => 'dri@b5m.com',
                   :from_alias => 'Matcher Message',
                   :subject => subject, 
                   :body => body})
    rescue Exception => e
      puts "send mail error #{e}"
    end

  end

private
  def check_db_valid path
    unless path.nil?
      unless File.directory? path
        raise "#{path} not a valid db path"
      end
    end
  end



end
