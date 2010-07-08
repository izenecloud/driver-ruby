# -*- ruby -*-

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/clean'
# require 'rake/testtask'

# task :default => [:test]
# Rake::TestTask.new do |t|
#   t.test_files = FileList['unit-test/**/test-*.rb']
#   t.verbose = true
# end

sf1_driver_spec = Gem::Specification.new do |s|
  s.version = "1.1.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "Sf1 Driver Ruby Client."
  s.name = "sf1-driver"
  s.requirements << "none"
  s.require_path = "lib"
  s.add_dependency "json"
  s.email = "it@izenesoft.com"
  s.homepage = "http://www.izenesoft.com"
  s.files = FileList['lib/sf1-driver/**/*.rb']
end

Rake::GemPackageTask.new(sf1_driver_spec) do |pkg|
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main = "lib/sf1-driver/connection.rb"
  rd.rdoc_files.include("lib/sf1-driver/**/*.rb")
  rd.options << "--all"
end

directory "../sf1-driver-docs/html/ruby-client"
task "rdoc:copy" => ["../sf1-driver-docs/html/ruby-client"] do
  sh "rsync -av --del html/ ../sf1-driver-docs/html/ruby-client"
end

task :websender do
  ruby "websender/server.rb"
end
