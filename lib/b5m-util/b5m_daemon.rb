require 'net/http'

class B5mDaemon

  attr_reader :ip, :port

  def initialize(ip="0.0.0.0",port=18190)
    @ip=ip
    @port = port
  end

  def run(cmd)

    puts "commiting #{cmd}"
    uri_str = "http://#{ip}:#{port}/?cmd=#{cmd}"
    uri_str = URI.escape(uri_str)
    uri = URI(uri_str)
    #puts "uri:#{uri_str}"
    begin
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.read_timeout = 3600*48
        request = Net::HTTP::Get.new(uri.request_uri)
        res = http.request(request)
        return res.is_a?(Net::HTTPSuccess)
      end
    rescue Exception => e
      puts "daemon run exception : #{e}"
      return false
    end
  end

end

