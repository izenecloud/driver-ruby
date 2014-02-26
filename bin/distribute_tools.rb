#!/usr/bin/env ruby
##
require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'optparse'
require 'json'
#
#
ip, port, request_file, collection = ARGV
sf1 = create_connection_withparam(ip, port)

request = ''
File.open(request_file) do |fs|
    request = JSON.load fs.read
    if request.nil? or request["uri"].nil?
        $stderr.puts "Must set the uri in request"
        return
    end
    if !collection.nil?
        request['collection'] = collection
    end
end

puts "=====command to #{ip}, #{request['collection']}, " + request['uri'] + "===== "

begin
    response = sf1.call(request['uri'], request)

    if response
        success = response["header"] && response["header"]["success"]
        if success
            puts "Success!"
        end
        if response["errors"]
            messages = response["errors"].join(" ").gsub(/[\n\r]/, "");
            $stderr.puts "[ERROR] #{messages}"
        end
        puts JSON.pretty_generate response
    else
        $stderr.puts "no response"
    end

rescue => e
    $stderr.puts "Exception: #{e}"
end

