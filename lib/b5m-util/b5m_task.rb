require_relative 'b5m_config.rb'
require_relative 'b5m_single_indexer.rb'
require_relative 'b5m_distribute_indexer.rb'
require_relative 'b5m_hdfs_indexer.rb'
require_relative 'b5m_m.rb'
require_relative 'b5m_mail.rb'
require_relative 'b5m_daemon.rb'
require 'sf1-util/scd_parser'
require 'sf1-util/sf1_logger'
require 'net/smtp'
require 'fileutils'

class B5mTask
  include Sf1Logger

  attr_accessor :email, :m, :scd, :train_scd, :comment_scd
  attr_reader :config, :instance_list, :m_list, :last_m, :last_rebuild_m, :last_o_m, :last_c_m, :last_odb, :last_codb, :last_cdb, :scd, :comment_scd, :last_db_m, :last_rebuild_m

  def initialize(config_file)
    @email = false
    if config_file.is_a? String
      @config = B5mConfig.new(config_file)
    else
      @config = config_file
    end
    @scd = config.path_of('scd')
    @train_scd = config.path_of('train_scd')
    @comment_scd = config.path_of('comment_scd')
    @indexer = nil
    indexer_type = "single"
    #indexer_type = @config['indexer']['type']
    #STDERR.puts "indexer type #{indexer_type}"
    if !@config['indexer']['type'].nil?
      indexer_type = @config['indexer']['type']
    end
    if indexer_type=="distribute"
      @indexer = B5mDistributeIndexer.new(@config['indexer'])
    elsif indexer_type=="hdfs"
      @indexer = B5mHdfsIndexer.new(@config['indexer'])
    else
      @indexer = B5mSingleIndexer.new(@config['indexer'])
    end
    @indexer.schema = config.schema
    unless config.name.nil?
      @indexer.schema = config.name
    end
    #@instance_list = []
    #@config.sf1_instances.each do |si|
      #instance = B5mSf1Instance.new(si, @config.name, @config.no_comment?)
      #@instance_list << instance
    #end
    @m_list = []
    @broken_m_list = []
    gen
  end

  def gen()
    unless File.exists? mdb
      FileUtils.mkdir_p(mdb)
    end
    #return if config.schema!="b5m"
    @m_list.clear
    @broken_m_list.clear
    Dir.foreach(mdb) do |m|
      next unless m =~ /\d{14}/
      mm = File.join(mdb, m)
      next unless File.directory?(mm)
      b5m_m = B5mM.new(mm)
      if b5m_m.broken?
        @broken_m_list << b5m_m
        #b5m_m.delete
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
    #check_valid
  end

  def clean(opt={})
    @broken_m_list.each do |m|
      m.delete
    end
    keep = 0
    keep = opt[:keep] unless opt[:keep].nil?
    if keep>0
      @m_list.each_with_index do |m, i|
        doclean = false
        doclean = true if @m_list.size-i>keep and File.exists? m.b5mo_mirror
        if doclean
          puts "keep clean #{m.b5mo_mirror}"
          FileUtils.rm_rf m.b5mo_mirror
        end
      end
    end
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
    m_config_file = File.join(m.path, "config")
    config.save(m_config_file)
    #then copy related db to the new m
    #if m.mode==0 and !last_odb.nil?
    #  puts "copy #{last_odb} to #{m.odb}"
    #  FileUtils.cp_r(last_odb, m.odb)
    #end

    #cmode==0 never happen now
    if m.cmode==0 and !last_cdb.nil?
      puts "copy #{last_cdb} to #{m.cdb}"
      FileUtils.cp_r(last_cdb, m.cdb)
    end
    scd_path = scd
    if m.mode==0 #incremental
      scd_path = File.join(scd, "incremental")
    else
      scd_path = File.join(scd, "rebuild")
    end
    unless File.directory?(scd_path)
      scd_path = scd
    end
    comment_scd_path = comment_scd
    puts "offer-scd:#{scd_path}"
    puts "comment-scd:#{comment_scd_path}"
    if !comment_scd_path.nil?
      comment_scd_list = ScdParser.get_scd_list(comment_scd_path)
      if comment_scd_list.empty?
        puts "comment scd empty, set cmode=-1"
        m.cmode = -1
      end
    else
      m.cmode = -1
    end
    cma = config.path_of('cma')
    mobile_source = config.path_of('mobile_source')
    human_match = config.path_of('human_match')
    daemon = B5mDaemon.new
    if config.schema=="b5m"
      unless File.exists? knowledge
        FileUtils.mkdir_p knowledge
      end
      #do product training
      cmd = "--product-train -S #{train_scd} -K #{knowledge} --mode #{m.mode} -C #{cma}"
      unless config.thread_num.nil?
        cmd += " --thread-num #{config.thread_num}"
      end
      if config.use_psm?
        cmd += " --use-psm"
      end
      unless daemon.run(cmd)
        abort("product train failed")
      end

      #b5mo generator, update odb here
      if m.mode>=0
        unless config.omapper.nil?
          FileUtils.mkdir m.omapper unless File.exists? m.omapper
          if config.omapper.start_with? 'http'
            uri = URI(config.omapper)
            Net::HTTP.start(uri.host, uri.port) do |http|
              http.read_timeout = 3600
              request = Net::HTTP::Get.new(uri.request_uri)
              res = http.request(request)
              File.open(m.omapper_data, 'w') do |f|
                f.write res.body
              end
            end
          else
            FileUtils.cp config.omapper, m.omapper_data
          end
        end
        cmd = "--b5mo-generate -S #{scd_path} -K #{knowledge} -C #{cma} --mode #{m.mode} --mdb-instance #{m}"
        cmd+=" --bdb #{bdb}"
        if !last_o_m.nil? and m.mode==0
          cmd+=" --last-mdb-instance #{last_o_m}"
        end
        unless config.thread_num.nil?
          cmd += " --thread-num #{config.thread_num}"
        end
        unless daemon.run(cmd)
          abort("b5mo generate failed")
        end
        #b5mp generator
        cmd = "--b5mp-generate --mdb-instance #{m}"
        if !last_o_m.nil? and m.mode==0
          cmd+=" --last-mdb-instance #{last_o_m}"
        end
        if config.spu_only?
          cmd+=" --spu-only"
        end
        unless config.thread_num.nil?
          cmd += " --thread-num #{config.thread_num}"
        end
        unless config.buffer_size.nil?
          cmd += " --buffer-size #{config.buffer_size}"
        end
        unless config.sorter_bin.nil?
          cmd += " --sorter-bin #{config.sorter_bin}"
        end
        unless daemon.run(cmd)
          abort("b5mp generate failed")
        end
      end

      if m.cmode>=0
        cname = File.basename(comment_scd_path)
        ctime = Time.at(0)
        if cname =~ /\d{14}/
          ctime = DateTime.strptime(cname, "%Y%m%d%H%M%S").to_time
        end
        m.ctime = ctime
        #b5mc generator
        cmd = "--b5mc-generate -S #{comment_scd_path} --mode #{m.cmode} --mdb-instance #{m}"
        if !last_c_m.nil? and m.cmode==0
          cmd+=" --last-mdb-instance #{last_c_m}"
        end
        unless config.thread_num.nil?
          cmd += " --thread-num #{config.thread_num}"
        end
        unless daemon.run(cmd)
          abort("b5mc generate failed")
        end
      end
    elsif config.schema=="ticket"
      cmd = "--ticket-generate -S #{scd_path} -C #{cma} --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("ticket generate failed")
      end
    elsif config.schema=="tuan"
      cmd = "--tuan-generate -S #{scd_path} -C #{cma} --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("tuan generate failed")
      end
    elsif config.schema=="tour"
      cmd = "--tour-generate -S #{scd_path} --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("tour generate failed")
      end
    else
      abort("schema error")
    end
    m.status = "matched"
    m.flush
    gen
  end

  #def matcher_finish
    #@m.status = "matched"
    #@m.flush
    #gen
  #end

  def apply(m, opt={})
    begin
      @indexer.index(m, opt)
    rescue Exception => e
      STDERR.puts "exception #{e} in indexing #{m}"
      raise e
    end
    if m.is_a? Array
      m.each do |im|
        im.status = "finished"
        im.flush
      end
    else
      m.status = "finished"
      m.flush
    end
  end

  def send_mail(m)
    return if m.nil?
    return if m.status!="finished" and m.status!="matched"
    puts "start to send mail at #{m}"
    subject = "Matcher (#{config.schema})"
    if m.mode>0
      subject += ' Rebuild'
    elsif m.mode==0
      subject += ' Incremental'
    elsif m.cmode>=0
      subject += ' Comment Only'
    end
    #subject += " to #{config.first_ip}"
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
    body += "b5mo update(rtype) doc count #{ou_count}\n"
    body += "b5mo delete doc count #{od_count}\n"
    body += "b5mp update(rtype) doc count #{pu_count}\n"
    body += "b5mp delete doc count #{pd_count}\n"
    body += "b5mc update doc count #{cu_count}\n"
    body += "b5mc delete doc count #{cd_count}\n"


    begin

      B5mMail.send({:host => 'localhost', 
                   :to => ['matcher_notify@b5m.com'],
                   :from => 'matcher_notify@b5m.com',
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
