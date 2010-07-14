#!/usr/bin/env ruby
#---
# Author::  Ian Yang
# Created:: <2010-06-22 16:35:16>
#+++
require File.join(File.dirname(__FILE__), "common")
require 'optparse'

request = {
  :collection => nil,
  :document_count => 0
}

opts = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{__FILE__} [OPTIONS] command collection"

  opts.separator ''

  opts.on("--document-count COUNT", "-n", Integer,
          "Document count limit (for debug)") do |n|
    request[:document_count] = n
  end

  opts.on_tail("--help", "-h", "Print this help") do
    puts opts
    exit
  end
end

opts.parse!

command, request[:collection] = ARGV

if command.nil? or request[:collection].nil?
  STDERR.puts "Require command and collection."
  exit 1
end

conn = create_connection
response = conn.call("commands/#{command}", request)

if response.nil? or !response["header"]["success"]
  STDERR.puts "ERROR!"
  if response["errors"]
    STDERR.puts response["errors"].join("\n")
  end
  exit 1
elsif response["warnings"]
  puts "WARNING!"
  puts response["warnings"].join("\n")
else
  puts "Sent!"
end
