#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'optparse'
require 'json'

def search_request_template(collection, keywords)
  @request = {
    :collection => collection,
    :search => {
      :keywords => keywords,
      :searching_mode => {:mode => "zambezi"}
      }
    }
end

title_file = ARGV[0]
#puts title_file

unless File.exist? title_file 
  $stderr.puts "File does not exist: #{title_file}"
end

conn = create_connection
cate_file = File.new("title_original_category", "w+")
n = 0;
begin
  File.open(title_file).each do |record|
    table = record.index("\t")
    if nil == table
      next
    end
    query = record[0, table]
    title = record[table + 1, record.size()]
    #puts(query);
    #puts(title);
    request = search_request_template("b5mp", title)
    response = conn.call("documents/search", request)
    if response["errors"]
      next
    end
    if nil == response["resources"]
      request = search_request_template("b5mp", title[0, title.size() / 2]);
      response = conn.call("documents/search", request)
    end
    if nil != response["resources"]
      cate_file.write(query + "\t" + response["resources"][0]["OriginalCategory"] + "\n")
    end
    n += 1
    if (n % 100 == 0)
      puts "finished records = " + n.to_s
    end
  end
end
