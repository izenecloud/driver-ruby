require 'sf1-driver'
require 'httpclient'
class Sf1DriverOrNginx
  def initialize(ip, port, nginx_postfix=nil)
    @ip = ip
    @port = port
    @nginx_postfix = nginx_postfix
    @conn = nil
    @client = nil
    if !nginx_postfix.nil?
      @client = HTTPClient.new
    else
      @conn = Sf1Driver.new(ip, port)
    end
  end

  def call(api, body)
    begin
      if !@nginx_postfix.nil?
        return @client.post("http://#{@ip}:#{@port}/#{@nginx_postfix}/#{api}", body)
      else
        return @conn.call(api, body)
      end
    rescue Exception => e
      STDERR.puts "call exception #{e}"
      return nil
    end
  end

  def host
    
    @ip
  end
end
