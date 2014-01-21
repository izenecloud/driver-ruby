require 'fileutils'
require 'logger'
require 'b5m-util/b5m_config'
require 'b5m-util/b5m_task'
require 'b5m-util/b5m_m'
require 'b5m-util/b5m_input_scd'
require 'b5m-util/b5m_omapper'
require 'sf1-util/scd_type_writer'

class B5mDriver
  attr_reader :config
  attr_accessor :rounds_limit, :m
  def initialize(config_file)
    @logger = Logger.new(STDERR)
    @config = B5mConfig.new(config_file)
    @rounds_limit = 0
  end

  def run
    schema = config.schema
    mode = 0 #B5MMode::INC as default
    cmode = -1 #no comment process as default
    #if schema!="b5m"
    #  mode = 3
    #  cmode = -1
    #end
    task = B5mTask.new(config)
    task.clean(:keep => 5)
    last_m_time = Time.at(0)
    unless task.last_m.nil?
      last_m_time = task.last_m.time
    end
    #last_rebuild_time = Time.at(0)
    #unless task.last_rebuild_m.nil?
    #  last_rebuild_time = task.last_rebuild_m.time
    #end
    #if schema=="b5m" and task.m_list.empty?
    #  mode = 1
    #  cmode = 1
    #end
    mname = B5mM.get_a_name
    if config.monitor?
      auto_rebuild = config.auto_rebuild
      if auto_rebuild.nil?
        auto_rebuild = config.schema=="b5m"? false : true
      end
      #to set mode, cmode and input_scd_list below
      input_scd_list = B5mInputScd.get_all(File.join(config.path_of('scd'), "incremental"), config.scd_done_name, last_m_time)
      rebuild_scd_list = B5mInputScd.get_all(File.join(config.path_of('scd'),"rebuild"), config.scd_done_name, last_m_time)
      if auto_rebuild
        unless rebuild_scd_list.empty?
          input_scd_list = [rebuild_scd_list.last]
          mode = 1
        end
      elsif task.m_list.empty?
        input_scd_list = [rebuild_scd_list.last]
        mode = 1
      end
      if config.schema=="b5m" and mode>0
        cmode = 1
      end
      #if mode>0
      #  rebuild_scd_list = B5mInputScd.get_all(File.join(task.scd,"rebuild"), config.scd_done_name, last_rebuild_time)
      #  if rebuild_scd_list.empty?
      #    input_scd_list = []
      #  else
      #    input_scd_list = [rebuild_scd_list.last]
      #  end
      #elsif mode==0
      #  start_time = Time.at(0)
      #  unless task.last_m.nil?
      #    start_time = task.last_m.time
      #  end
      #  input_scd_list = B5mInputScd.get_all(File.join(task.scd, "incremental"), config.scd_done_name, start_time)
      #end
      if cmode>0
        input_comment_scd = B5mInputScd.get_all(File.join(config.path_of('comment_scd'), "rebuild"), config.scd_done_name).last
      else
        input_comment_scd = nil
      end
      if input_scd_list.empty?
        input_scd = nil
      elsif input_scd_list.size==1 or config.schema=="__other"
        input_scd = input_scd_list.first.path
        mname = input_scd_list.first.name
      else
        input_b5m_scd = merge_scd(input_scd_list)
        input_scd = input_b5m_scd.path
        mname = input_b5m_scd.name
      end
      input_comment_scd = input_comment_scd.path unless input_comment_scd.nil?
    end
    unless input_scd.nil?
      m = B5mM.new(task.mdb, mname)
      m.mode = mode
      m.cmode = cmode
      m.scd = input_scd
      unless input_comment_scd.nil?
        m.comment_scd = input_comment_scd
        comment_scd_list = ScdParser.get_scd_list(m.comment_scd)
        if comment_scd_list.empty?
          m.cmode = -1
          m.comment_scd = nil
        end
      end

      #if m.cmode==0 and !input_lastcm.nil?
        #task.set_last_c_m(input_lastcm)
      #end
      last_start_time = Time.now
      task.print_last
      if m.exists?
        raise "m #{@m} already exists"
      end
      scd_path = m.scd
      if m.mode==0 #incremental
        scd_path = File.join(m.scd, "incremental")
      else
        scd_path = File.join(m.scd, "rebuild")
      end
      if File.directory?(scd_path)
        m.scd = scd_path
      end
      m.knowledge = File.join(config.path_of("work_dir"), "knowledge")
      @logger.info "schema:#{schema}"
      @logger.info "mode:#{mode}"
      @logger.info "cmode:#{cmode}"
      @logger.info "input_scd:#{m.scd}"
      @logger.info "input_c_scd:#{m.comment_scd}"
      @logger.info "knowledge:#{m.knowledge}"
      m.create(config)
      if schema!="__other"
        task.matcher_start m
      else
        #schema=='__other'
        unless config.omapper.nil?
          do_omapper(m, config.omapper)
        end
      end
      opt = {:scd_only => config.noindex?}
      unless config.noapply?
        task.apply(m, opt)
      end
      task.send_mail(m) if config.send_mail?
    end
    
  end
  def start

    #default parameters
    schema = config.schema
    last_start_time = nil
    rounds = 0
    while true

      mode = 0 #B5MMode::INC as default
      cmode = -1 #no comment process as default
      if schema!="b5m"
        mode = 3
        cmode = -1
      end
      if mode>=3
        FileUtils.rm_rf config.path_of('work_dir')
      end
      task = B5mTask.new(config)
      task.clean(:keep => 5)
      #task.m_release
      if schema=="b5m" and task.m_list.empty?
        mode = 1
        cmode = 1
      end
      mname = B5mM.get_a_name
      input_scd = task.scd
      input_comment_scd = task.comment_scd
      if config.monitor?
        input_scd_list = []
        if mode>0
          rebuild_scd_list = B5mInputScd.get_all(File.join(task.scd,"rebuild"), config.scd_done_name)
          if rebuild_scd_list.empty?
            input_scd_list = []
          else
            input_scd_list = [rebuild_scd_list.last]
          end
        elsif mode==0
          start_time = Time.at(0)
          unless task.last_m.nil?
            start_time = task.last_m.time
          end
          input_scd_list = B5mInputScd.get_all(File.join(task.scd, "incremental"), config.scd_done_name, start_time)
        end
        if cmode>0
          input_comment_scd = B5mInputScd.get_all(File.join(task.comment_scd, "rebuild"), config.scd_done_name).last
        else
          input_comment_scd = nil
        end
        if input_scd_list.empty?
          input_scd = nil
        elsif input_scd_list.size==1
          input_scd = input_scd_list.first.path
          mname = input_scd_list.first.name
        else
          input_b5m_scd = merge_scd(input_scd_list)
          input_scd = input_b5m_scd.path
          mname = input_b5m_scd.name
        end
        input_comment_scd = input_comment_scd.path unless input_comment_scd.nil?
      end
      unless input_scd.nil?
        m = B5mM.new(task.mdb, mname)
        m.mode = mode
        m.cmode = cmode
        @logger.info "schema:#{schema}"
        @logger.info "mode:#{mode}"
        @logger.info "cmode:#{cmode}"
        task.scd = input_scd
        task.comment_scd = input_comment_scd
        @logger.info "input_scd:#{task.scd}"
        @logger.info "input_c_scd:#{task.comment_scd}"
        @logger.info "input_t_scd:#{task.train_scd}"

        #if m.cmode==0 and !input_lastcm.nil?
          #task.set_last_c_m(input_lastcm)
        #end
        last_start_time = Time.now
        task.print_last
        task.matcher_start m
        opt = {:scd_only => config.noindex?}
        unless config.noapply?
          task.apply(m, opt)
          task.send_mail(m) if config.send_mail?
        end
        rounds+=1
      end
      
      unless config.monitor?
        break
      end
      if @rounds_limit>0 and rounds>=@rounds_limit
        break
      end
      sleep_time = config.monitor_interval
      if m.nil?
        sleep_time = 1800
      else
        sleep_time = 30 if sleep_time<30
        sleep_time*=5 if m.mode>0
      end
      @logger.info "now sleep #{sleep_time} seconds"
      #unless last_start_time.nil?
        #this_start_time = last_start_time + config.monitor_interval
        #sleep_time = this_start_time - Time.now
      #end

      sleep(sleep_time) if sleep_time>0
      #sleep 30.0
    end
  end

private
  def merge_scd(input_list)
    input_cache_dir = File.join(config.tmp_dir, ".merge_input")
    output_cache_dir = File.join(config.tmp_dir, ".merge_output")
    FileUtils.rm_rf input_cache_dir if File.exists? input_cache_dir
    FileUtils.rm_rf output_cache_dir if File.exists? output_cache_dir
    FileUtils.mkdir_p input_cache_dir
    input_list.each do |input|
      scd_list = ScdParser.get_scd_list(input.path)
      scd_list.each do |scd|
        FileUtils.cp scd, input_cache_dir
      end
    end
    last_input = input_list.last
    output_dir = File.join(output_cache_dir, last_input.name)
    FileUtils.mkdir_p output_dir
    daemon = B5mDaemon.new
    daemon.run("--scd-merge -I #{input_cache_dir} -O #{output_dir} --all --imc #{config.imc}")
    #system("ScdMergeTool -I #{input_cache_dir} -O #{output_dir} --gen-all")
    #FileUtils.rm_rf input_cache_dir
    output_scd_list = ScdParser.get_scd_list(output_dir)
    abort "output scd list empty" if output_scd_list.empty?
    done_file = File.join(output_dir, "done")
    File.open(done_file, 'w') do |f|
      f.puts 'a'
    end

    B5mInputScd.new(output_dir)
  end

  def do_omapper(m, omapper)
    input_scd_list = ScdParser.get_scd_list(m.scd)
    #output_path = m.local_b5mo
    output_path = m.b5mo
    FileUtils.rm_rf output_path if File.exists? output_path
    FileUtils.mkdir_p(output_path)
    writer = ScdTypeWriter.new(output_path)
    om = B5mOmapper.new(omapper)
    input_scd_list.each do |scd|
      parser = ScdParser.new(scd)
      type = ScdParser.scd_type(scd)
      @logger.info "OMapper processing scd #{scd}"
      parser.each_with_index do |doc, i|
        @logger.info "OMapper processing doc #{i}" if i%100000==0
        category = om.get_category(doc)
        unless category.nil?
          doc['Category'] = category
        end
        writer.append(doc, type)
      end
    end
    writer.close
    m.scd = output_path
  end

end
