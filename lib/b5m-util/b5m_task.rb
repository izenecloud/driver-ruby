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
require 'logger'

class B5mTask
  include Sf1Logger

  attr_accessor :email, :m, :train_scd
  attr_reader :config, :instance_list, :m_list, :last_m, :last_rebuild_m, :last_c_m, :last_complete_m

  def initialize(config_file)
    @logger = Logger.new(STDERR)
    @email = false
    if config_file.is_a? String
      @config = B5mConfig.new(config_file)
    else
      @config = config_file
    end
    @train_scd = config.path_of('train_scd')
    @indexer = nil
    indexer_type = "single"
    #indexer_type = @config['indexer']['type']
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
    @last_c_m = nil
    @m_list.reverse_each do |em|
      if em.cmode>=0 #do b5mc
        @last_c_m = em
        break
      end
    end
    @last_rebuild_m = nil
    @m_list.reverse_each do |em|
      if em.mode>0
        @last_rebuild_m = em
        break
      end
    end
    @last_complete_m = nil
    @m_list.reverse_each do |em|
      unless em.rtype?
        @last_complete_m = em
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
      ikeep = 0
      @m_list.reverse_each do |m|
        if File.exists? m.b5mo_mirror
          ikeep+=1
          if ikeep>keep
            @logger.info "minimize m #{m}"
            FileUtils.rm_rf m.b5mo_mirror
            FileUtils.rm_rf m.b5mo_block
            FileUtils.rm_rf m.odb
          end
        end
      end
      #@m_list.each_with_index do |m, i|
      #  doclean = false
      #  doclean = true if @m_list.size-i>keep and File.exists? m.b5mo_mirror
      #  if doclean
      #    @logger.info "minimize m #{m}"
      #    FileUtils.rm_rf m.b5mo_mirror
      #    FileUtils.rm_rf m.b5mo_block
      #  end
      #end
    end
  end

  def print_last
    @logger.info "last_m #{@last_m}"
    @logger.info "last_rebuild_m #{@last_rebuild_m}"
    @logger.info "last_c_m #{@last_c_m}"
    @logger.info "last_complete_m #{@last_complete_m}"
  end

  def copy_m(from_m)
    target_m = File.join(mdb, from_m.name)
    if File.exists? target_m
      @logger.error "#{target_m} exists, copy_m failed"
      return false
    end
    @logger.info "copy #{from_m.path} to #{target_m}"
    FileUtils.cp_r from_m.path, target_m
    @logger.info "copied"
    return true
  end

  def work_dir

    config.path_of('work_dir')
  end

  def db

    File.join(work_dir, "db")
  end

  def mdb
    
    File.join(db, "mdb")
  end


  def matcher_start(m)
    @m = m
    m.status = "matching"
    m.flush
    #then copy related db to the new m
    #if m.mode==0 and !last_odb.nil?
    #  puts "copy #{last_odb} to #{m.odb}"
    #  FileUtils.cp_r(last_odb, m.odb)
    #end

    last_o_m = @last_m
    unless m.rtype?
      last_o_m = @last_complete_m
    end
    cma = config.path_of('cma')
    #mobile_source = config.path_of('mobile_source')
    #human_match = config.path_of('human_match')
    daemon = B5mDaemon.new(config.matcher_ip, config.matcher_port)
    if config.schema=="b5m"
      unless File.exists? m.knowledge
        FileUtils.mkdir_p m.knowledge
      end
      #do product training
      cmd = "--product-train -S #{train_scd} -K #{m.knowledge} --mode #{m.mode} -C #{cma}"
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
        cmd = "--b5mo-generate --mdb-instance #{m}"
        if !last_o_m.nil? and m.mode==0
          cmd+=" --last-mdb-instance #{last_o_m}"
        end
        unless daemon.run(cmd)
          abort("b5mo generate failed")
        end
        #cmd = "--b5mo-check --mdb-instance #{m}"
        #if !last_o_m.nil? and m.mode==0
        #  cmd+=" --last-mdb-instance #{last_o_m}"
        #end
        #unless daemon.run(cmd)
        #  abort("b5mo check failed")
        #end
        #b5mp generator
        cmd = "--b5mp-generate --mdb-instance #{m}"
        if !last_o_m.nil? and m.mode==0
          cmd+=" --last-mdb-instance #{last_o_m}"
        end
        unless daemon.run(cmd)
          abort("b5mp generate failed")
        end
      end

      if m.cmode>=0
        cname = File.basename(m.comment_scd)
        ctime = Time.at(0)
        if cname =~ /\d{14}/
          ctime = DateTime.strptime(cname, "%Y%m%d%H%M%S").to_time
        end
        m.ctime = ctime
        #b5mc generator
        cmd = "--b5mc-generate --mdb-instance #{m}"
        if !last_c_m.nil? and m.cmode==0
          cmd+=" --last-mdb-instance #{last_c_m}"
        end
        unless daemon.run(cmd)
          abort("b5mc generate failed")
        end
      end
    elsif config.schema=="ticket"
      cmd = "--ticket-generate --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("ticket generate failed")
      end
    elsif config.schema=="tuan"
      cmd = "--tuan-generate --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("tuan generate failed")
      end
    elsif config.schema=="tour"
      cmd = "--tour-generate --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("tour generate failed")
      end
    elsif config.schema=="hotel"
      cmd = "--hotel-generate --mdb-instance #{m}"
      unless daemon.run(cmd)
        abort("hotel generate failed")
      end
    else
      abort("schema error")
    end
    m.status = "matched"
    sleep 5.0
    m.count_scd
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
      if config.schema=="__other"
        sleep 5.0
        m.count_scd
        m.flush
      end
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
    @logger.info "start to send mail at #{m}"
    subject = "Matcher/Index (#{config.coll_name})"
    if m.mode>0
      subject += ' Rebuild'
    elsif m.mode==0
      subject += ' Incremental'
    elsif m.cmode>=0
      subject += ' Comment Only'
    end
    if config.schema=="b5m"
      subject += " (rtype #{m.rtype})"
    end
    #subject += " to #{config.first_ip}"
    subject += ' Finish'
    body = "schema #{config.schema}\n"
    body += "collection_name #{config.coll_name}\n"
    body += "working path #{m.path}\n"
    body += "timestamp #{m.name}\n"
    body += "o/p mode #{m.mode}\n"
    body += "c mode #{m.cmode}\n"
    body += "rtype #{m.rtype}\n"
    body += "start_time #{m.start_time}\n"
    #ou_count, od_count = ScdParser.get_ud_doc_count(m.b5mo)
    #pu_count, pd_count = ScdParser.get_ud_doc_count(m.b5mp)
    #cu_count, cd_count = ScdParser.get_ud_doc_count(m.b5mc)
    if m.ou_count>0
      body += "O insert/update/rtype doc count #{m.ou_count}\n"
    end
    if m.od_count>0
      body += "O delete doc count #{m.od_count}\n"
    end
    if m.pu_count>0
      body += "P insert/update/rtype doc count #{m.pu_count}\n"
    end
    if m.pd_count>0
      body += "P delete doc count #{m.pd_count}\n"
    end
    if m.cu_count>0
      body += "C update doc count #{m.cu_count}\n"
    end
    if m.cd_count>0
      body += "C delete doc count #{m.cd_count}\n"
    end

    begin

      B5mMail.send({:host => 'localhost', 
                   :to => ['matcher_notify@b5m.com'],
                   :from => 'matcher_notify@b5m.com',
                   :from_alias => 'Matcher Message',
                   :subject => subject, 
                   :body => body})
    rescue Exception => e
      @logger.error "send mail error #{e}"
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

