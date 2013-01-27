require 'fileutils'
require 'yaml'

class Sf1rResource

  attr_reader :config, :force
  def initialize(config_file, force = false)
    @config = YAML.load_file(config_file)
    @force = force
  end

  def method_missing(method_sym, *arguments)
    method = method_sym.to_s
    return @config[method]
  end

  def pull(dest=nil)
    modules = pull_sub_modules
    modules = sub_modules if modules.nil?
    abort("modules not found") if modules.nil?
    modules.each do |m|
      pull_module(m, dest)
    end
  end

  def push(source=nil)
    modules = push_sub_modules
    modules = sub_modules if modules.nil?
    abort("modules not found") if modules.nil?
    modules.each do |m|
      push_module(m, source)
    end
  end

private

  def add_lock
    meta = {:user => Etc.getlogin, :time => Time.now}
    system("ssh #{server} \"echo '#{meta.to_yaml}' > #{remote_lock_file}\"")
  end

  def wait_until_lock_free
    content = remote_lock_file_content
    return if content.empty?
    begin
      meta = YAML.load(content)
    rescue Exception => e
      STDERR.puts "parse remote lock file err #{e}"
      return
    end
  end


  def remote_lock_file_content
    cmd = "ssh #{server} \"test -f #{remote_lock_file} && cat #{remote_lock_file}\""
    content = `#{cmd}`

    content
  end

  def remote_lock_file

    "#{remote_path}/.#{branch}.lock"
  end

  def pull_module(m, dest=nil, sub_dir_name = nil)
    dest = local_path if dest.nil?
    raise "dest nil" if dest.nil?
    FileUtils.mkdir_p dest unless File.directory? dest
    m_dest = nil
    if sub_dir_name.nil?
      m_dest = File.join(dest, m)
      if File.directory? m_dest and !force
        #mv for backup
        backup_dest = File.join(dest, "."+m+".localbk")
        FileUtils.rm_rf backup_dest if File.exists? backup_dest
        FileUtils.mv m_dest, backup_dest
      end
    else
      m_dest = File.join(dest, sub_dir_name)
      if File.directory? m_dest
        FileUtils.rm_rf m_dest
      end
    end
    cmd = sync_cmd(remote_full_path(m), m_dest)
    system(cmd)
    unless $?.success?
      STDERR.puts "#{cmd} failed"
    end
  end

  def push_module(m, source=nil)
    source = local_path if source.nil?
    raise "source nil" if source.nil?
    raise "#{source} does not exist" unless File.directory? source
    m_source = File.join(source, m)
    unless force
      m_backup_name = "."+m+".remotebk"
      pull_module(m, source, m_backup_name)
    end
    raise "#{m_source} does not exist" unless File.directory? m_source
    cmd = sync_cmd(m_source, remote_full_path(m))
    system(cmd)
    unless $?.success?
      raise "#{cmd} failed"
    end
  end

  def remote_full_path(m)

    p = "#{server}:#{remote_path}/#{branch}"
    unless branch_suffix.nil?
      p += "/#{branch_suffix}"
    end
    p += "/#{m}"

    p
  end

  def sync_cmd(from, to)
    cmd = "rsync -azvP --delete #{from}/ #{to}/"
    STDERR.puts cmd

    cmd
  end

end

