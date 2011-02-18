#!/usr/bin/env ruby
#---
# Author::  Jun Jiang
# Created:: <2011-01-26 17:57:06>
#+++
#
require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'json'

if ARGV.size < 2
    puts "Usage: ruby #{__FILE__} json_template query_log"
    exit 1
end

request = nil
conn = create_connection

json_fname = ARGV[0]
File.open(json_fname, "r") do |fs|
    request = JSON.load fs.read
    if request.nil? or request["uri"].nil?
        $stderr.puts "Must set the uri in request: #{json_fname}"
    end

    request["header"] = {"check_time" => true}

    response = conn.call(request["uri"], request)
    puts "omitting the 1st query time: #{response["timers"]["process_time"]}"
end

query_num = 0
total_time = 0

query_fname = ARGV[1]
File.open(query_fname, "r") do |fs|
    while query = fs.gets
        query.chomp!
        next if query.empty?

        request["search"]["keywords"] = query
        response = conn.call(request["uri"], request)
        print "* #{query}: "
        if response
            if response["header"] && response["header"]["success"]
            total_time += response["timers"]["process_time"]
            query_num += 1
            puts "#{response["timers"]["process_time"]}, current query num: #{query_num}, current total time: %.2f, current average time: %.4f" % [total_time, total_time / query_num]
            end

            if response["errors"]
            messages = response["errors"].join(" ").gsub(/[\n\r]/, "");
            puts "[ERROR] #{messages}"
            elsif response["warnings"]
            messages = response["warnings"].join(" ").gsub(/[\n\r]/, "");
            puts "[WARN] #{messages}"
            end
        else
            puts "no response"
        end
    end
end

puts "query num: #{query_num}"
puts "total time: #{total_time}"
if query_num == 0
    puts "no query executed"
else
    avg_time = total_time / query_num
    puts "average time: %.4f" % avg_time
end
