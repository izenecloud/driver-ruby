# -*- ruby -*-

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/clean'

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'sf1-driver'

begin
  require 'spec/rake/spectask'

  desc "Run all examples"
  Spec::Rake::SpecTask.new do |t|
    t.spec_files = FileList['spec/**/*-test.rb']
    t.spec_opts = ["--require", File.expand_path(File.join("spec", "spec-helper.rb")),
                   "--format", "nested"]
  end
rescue LoadError
  desc 'Spec task not available'
  task :spec do
    abort 'Spec task is not available. Be sure to install  as a gem or plugin'
  end
end

sf1_driver_spec = Gem::Specification.new do |s|
  s.name = "sf1-driver"
  s.autorequire = "sf1-driver"
  s.version = Sf1Driver::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.summary = "Sf1 Driver Ruby Client."
  s.description = s.summary
  s.authors = ["Ian Yang"]
  s.email = "it@izenesoft.com"
  s.requirements << "none"
  s.require_path = "lib"
  s.add_dependency "json"
  s.add_dependency "eventmachine"
  s.homepage = "https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/index.html"
  s.files = %w(README.md Rakefile lib/sf1-driver.rb) + Dir.glob("lib/sf1-driver/**/*")
end

Rake::GemPackageTask.new(sf1_driver_spec) do |pkg|
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main = "lib/sf1-driver.rb"
  rd.rdoc_files.include("lib/sf1-driver.rb", "lib/sf1-driver/**/*.rb")
  rd.options << "--all"
end

directory "../sf1-driver-docs/html/ruby-client"
task "rdoc:copy" => ["../sf1-driver-docs/html/ruby-client"] do
  sh "rsync -av --del html/ ../sf1-driver-docs/html/ruby-client"
end

task :websender do
  ruby "websender/server.rb"
end
