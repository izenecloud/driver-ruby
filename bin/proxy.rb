libdir = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), "lib")
$LOAD_PATH << libdir

require "rubygems"
require "yaml"
require "json"
require "em-proxy"
require "sf1-driver/connection"

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
    conn = Sf1Driver::Connection.new(ba[:IP], ba[:Port])
    response = conn.send('hello/index',{})
    response["collections"].split(',').each do|collection|
      COLLECTIONMAP[collection] = cobra[0]
    end
  end 
end

Proxy.start(:host => "0.0.0.0", :port => CONFIG[:Port], :debug => false) do |conn|
  @start = Time.now
  @data = Hash.new("")
  
  CONFIG[:Cobras].each do |cobra|
    ba = cobra[1]
    if ba.is_a? Hash
      conn.server cobra[0], :host => ba[:IP], :port => ba[:Port]
    end 
  end

  conn.on_data do |data|
    request = JSON.parse(data.slice(Sf1Driver::Connection::INT_SIZE * 2,data.size))
    [data,COLLECTIONMAP[request["collection"]]]
  end
 
  conn.on_response do |server, resp|
    resp
  end

  conn.on_finish do |name|
    p [:on_finish, name, Time.now - @start]
    p @data
  end
end
