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

task :package_doc do
  mkdir "sf1-driver-docs" rescue nil
  sh_markdown = <<SH
cat README.md | sed 's;https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/;;' | markdown
SH
  body = `#{sh_markdown}`.sub(/<h1>.*<\/h1>/, "")

  File.open("sf1-driver-docs/index.html", "w") do |fs|
    fs.write <<HEADER
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/xhtml;charset=UTF-8"/>
<title>SF1 Driver</title>
<link href="html/tabs.css" rel="stylesheet" type="text/css"/>
<link href="html/doxygen.css" rel="stylesheet" type="text/css"/>
</head>
<body>
<div class="header">
  <div class="headertitle">
    <h1>SF1 Driver Ruby</h1>
  </div>
</div>

<div class="contents">
HEADER

    fs.write body

    fs.write <<FOOTER
</div>
</body>
</html>
FOOTER
  end

  sh "rsync -av --del ../sf1-driver-docs/html/ sf1-driver-docs/html"

  sh "zip -r sf1-driver-docs sf1-driver-docs"
end
