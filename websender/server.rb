libdir = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), "lib")
$LOAD_PATH << libdir

require "webrick"
include WEBrick

require File.join(File.dirname(__FILE__), "sender-servlet.rb")

def start_webrick(config = {})
  server = HTTPServer.new(config)
  yield server if block_given?
  ["INT", "TERM"].each {|signal| 
    trap(signal) {server.shutdown}
  }
  server.start
end

current_dir = File.dirname(File.expand_path(__FILE__)).freeze

config_file = File.join(current_dir, "server.yml")
unless File.exist? config_file
  config_file = File.join(current_dir, "server.yml.default")
end

CONFIG = YAML::load_file config_file

start_webrick(CONFIG) {|server|
  doc_root = File.dirname(__FILE__)
  server.mount("/", HTTPServlet::FileHandler, doc_root,
               {:FancyIndexing=>true})
  server.mount("/sender", SenderServlet)
}
