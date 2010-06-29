# -*- ruby -*-

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/clean'
# require 'rake/testtask'

# task :default => [:test]
# Rake::TestTask.new do |t|
#   t.test_files = FileList['unit-test/**/test-*.rb']
#   t.verbose = true
# end

sf1_driver_spec = Gem::Specification.new do |s|
  s.version = 1.1
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

