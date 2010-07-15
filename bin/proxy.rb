libdir = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), "lib")
$LOAD_PATH << libdir

require "rubygems"
require "yaml"
require "json"
require "em-proxy"
require "sf1-driver"

current_dir = File.dirname(File.expand_path(__FILE__)).freeze

config_file = File.join(current_dir, "proxy.yml")
unless File.exist? config_file
  config_file = File.join(current_dir, "proxy.yml.default")
end

COLLECTIONMAP = {}

CONFIG = YAML::load_file config_file
CONFIG[:Cobras].each do |cobra|
  ba = cobra[1]
  if ba.is_a? Hash
    begin
      conn = Sf1Driver.new(ba[:IP], ba[:Port])
      response = conn.call('schema',{})
      response["collections"].each do|collection|
        COLLECTIONMAP[collection] = [cobra[0],ba[:IP],ba[:Port]]
      end
    rescue => e
      puts "Can not connect to ",ba[:IP],ba[:Port]
    end
  end 
end

Proxy.start(:host => "0.0.0.0", :port => CONFIG[:Port], :debug => false) do |conn|
  @start = Time.now
  
  conn.on_data do |data|
    request = JSON.parse(data.slice(Sf1Driver::Helper::header_size,data.size))
    serverinfo = COLLECTIONMAP[request["collection"]]
    if serverinfo.nil?
      #collection does not exist, we forward it to any cobra
      CONFIG[:Cobras].each do |cobra|
        ba = cobra[1]
        if ba.is_a? Hash
          conn.server cobra[0], :host => ba[:IP], :port => ba[:Port]
        end 
      end      
      data
    else    
      conn.server serverinfo[0], :host => serverinfo[1], :port => serverinfo[2]
      [data,serverinfo[0]]
    end
  end
 
  conn.on_response do |server, resp|
    resp
  end

  conn.on_finish do |name|
    p [:on_finish, name, Time.now - @start]
  end
end

