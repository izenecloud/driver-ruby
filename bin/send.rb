#---
# Author::  Ian Yang
# Created:: <2010-06-22 17:57:06>
#+++
#
require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'optparse'
require 'json'

opts = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{__FILE__} input-files ..."

  opts.separator ''

  opts.on_tail("--help", "-h", "Print this help") do
    puts opts
    exit
  end
end

files = ARGV

conn = create_connection
responses = conn.batch do
  files.each do |file_path|
    unless File.exist? file_path
      $stderr.puts "File does not exist: #{file_path}"
    end

    begin
      File.open(file_path) do |fs|
        request = JSON.load fs.read
        if request.nil? or request["uri"].nil?
          $stderr.puts "Must set the uri in request: #{file_path}"
        end

        conn.send(request["uri"], request)
      end
    rescue => e
      $stderr.puts "Exception for file #{file_path}: #{e}"
    end
  end
end

responses.length.times do |i|
  out_file_path = files[i].sub(/(\.in)?\.js(on)?$/i, "")
  out_file_path += ".out.json"

  File.open(out_file_path, "w") do |fs|
    response = responses[i]
    if response
      fs.write JSON.pretty_generate response
    else
      fs.write "nil"
    end
  end
end

