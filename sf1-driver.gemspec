require File.join(File.dirname(__FILE__), 'lib', 'sf1-driver.rb')

Gem::Specification.new do |s|
  s.name = "sf1-driver"
  s.version = Sf1Driver::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.summary = "Sf1 Driver"
  s.description = "Provided several sf1r related libraries and binaries."
  s.authors = ["Ian Yang", "Jia Guo"]
  s.email = "it@izenesoft.com"
  s.requirements << "none"
  s.require_path = "lib"
  s.add_dependency "json"
  s.add_dependency "eventmachine"
  s.add_dependency "mail"
  s.homepage = "https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/index.html"
  s.files = %w(README.md Rakefile lib/sf1-driver.rb) + Dir.glob("lib/sf1-driver/**/*") + Dir.glob("lib/sf1-util/*") + Dir.glob("lib/b5m-util/*") + Dir.glob("lib/sf1-resource/*")
  s.executables << 'sf1r-resource'
 
end

