require 'webrick'
include WEBrick

def start_webrick(config = {})
  config.update(:Port => 18188)
  config.update(:MimeTypes => {
                  'rhtml' => 'text/html',
                  'js' => 'application/x-javascript',
                  'css' => 'text/css'
                })
  server = HTTPServer.new(config)
  yield server if block_given?
  ['INT', 'TERM'].each {|signal| 
    trap(signal) {server.shutdown}
  }
  server.start
end

start_webrick {|server|
  doc_root = File.dirname(__FILE__)
  server.mount("/", HTTPServlet::FileHandler, doc_root,
               {:FancyIndexing=>true})
}


