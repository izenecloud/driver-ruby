
class FileObject
  attr_reader :path, value
  def initialize(path, class_type)
    @path = path
    @value = nil
    @class_type = class_type
    if File.exists?(path)
      unless File.file?(path)
        raise "#{path} not a regular file"
      end
      content = nil
      File.open(path, 'r') do |f|
        content = f.readline
      end
      unless content.nil?
        @value = @class_type(content)
      end
    end
  end

  def value=(v)
    File.open(path, 'w') do |f|
      f.puts(v)
    end
    @value = v
  end
end
