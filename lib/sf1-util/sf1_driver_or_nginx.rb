require 'sf1-driver'
require 'httpclient'
require 'json'
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

  def call(api, body, tokens="")
    begin
      if !@nginx_postfix.nil?
        r = @client.post_content("http://#{@ip}:#{@port}/#{@nginx_postfix}/#{api}", body.to_json, 'Content-Type' => 'application/json')
        if r.is_a? String
          r = JSON.parse(r)
        end
        return r
      else
        return @conn.call(api, body, tokens)
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
