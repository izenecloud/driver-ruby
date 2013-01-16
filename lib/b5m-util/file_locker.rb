
class FileLocker

  attr_reader :value
  def initialize(file_path, lock_const = File::LOCK_EX)
    @logger = Logger.new(STDERR)
    begin
      file_path = File.expand_path(file_path)
      unless File.exists?(file_path)
        this_file = File.new(__FILE__)
        this_file.flock(File::LOCK_EX)
        unless File.exists?(file_path)
          File.open(file_path, 'w') do |f|
            f.puts 'a'
          end
        end
        this_file.flock(File::LOCK_UN)
      end
      if File.exists?(file_path)
        @lock_file = File.new(file_path)
        @logger.info "FileLocker on #{file_path}..."
        @value = @lock_file.flock(lock_const)
        @logger.info "file lock got"
      else
        raise "#{file_path} not exists"
      end
    rescue Exception => e
      abort "FileLocker error #{e}"
    end

  end
end
