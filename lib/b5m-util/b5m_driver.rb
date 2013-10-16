require 'fileutils'
require 'b5m-util/b5m_config'
require 'b5m-util/b5m_task'
require 'b5m-util/b5m_m'
require 'b5m-util/b5m_input_scd'

class B5mDriver
  attr_reader :config
  attr_accessor :rounds_limit
  def initialize(config_file)
    @config = B5mConfig.new(config_file)
    @rounds_limit = 0
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
          #STDERR.puts "input scd empty"
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
        puts "schema:#{schema}"
        puts "mode:#{mode}"
        puts "cmode:#{cmode}"
        task.scd = input_scd
        task.comment_scd = input_comment_scd
        puts "input_scd:#{task.scd}"
        puts "input_c_scd:#{task.comment_scd}"
        puts "input_t_scd:#{task.train_scd}"

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
      sleep_time = 30 if sleep_time<30
      sleep_time*=5 if m.mode>0
      STDERR.puts "now sleep #{sleep_time} seconds"
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
    daemon.run("--scd-merge -I #{input_cache_dir} -O #{output_dir} --all")
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

end
