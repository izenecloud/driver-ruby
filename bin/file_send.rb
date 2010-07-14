#!/usr/bin/env ruby
#---
# Author::  Jia Guo
# Created:: <2010-07-06>
#+++
#
require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'optparse'
require 'json'

opts = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{__FILE__} json-input query-file seconds ..."

  opts.separator ''

  opts.on_tail("--help", "-h", "Print this help") do
    puts opts
    exit
  end
end

jsonfile = ARGV[0]
puts jsonfile
queryfile = ARGV[1]
seconds = ARGV[2].to_i

unless File.exist? jsonfile
    $stderr.puts "File does not exist: #{jsonfile}"
    exit
end
request = nil
File.open(jsonfile) do |fs|
    request = JSON.load fs.read
    if request.nil? or request["uri"].nil?
        $stderr.puts "Must set the uri in request: #{jsonfile}"
        exit
    end
end


unless File.exist? queryfile
    $stderr.puts "File does not exist: #{queryfile}"
    exit
end

keywords = []
i_file = File.new(queryfile, "r")
i_file.each_line do |line|
    keywords.push(line)
end
i_file.close

start_sec = Time.now.to_i
conn = create_connection
loop {
    keywords.each do |keyword|
        responses = conn.batch do
            
                n_request = request.clone
                n_request["search"]["keywords"] = keyword
#                 puts n_request["search"]["keywords"]
                begin
                    conn.call(n_request["uri"], n_request)
                rescue => e
                    $stderr.puts "Exception : #{e}"
                end
                now_sec = Time.now.to_i
                if now_sec-start_sec>seconds
                    exit
                end
        end
    end
}
