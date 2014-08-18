
class B5mFs
  LOCAL = 1
  HDFS = 2

  def self.to_s(fs)
    if fs==LOCAL
      return "LOCAL"
    elsif fs==HDFS
      return "HDFS"
    else
      return "UNKNOW"
    end
  end
end

