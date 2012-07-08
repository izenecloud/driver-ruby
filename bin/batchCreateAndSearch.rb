#!/usr/bin/env ruby
#---
#  create documents into collection and perform batch search.
#+++
#
require File.join(File.dirname(__FILE__), "common")
require 'rubygems'
require 'optparse'
require 'json'


sf1 = create_connection
collectionName = "example"
randfile_name = "./randContentFile"
randlines = 0
# document num that will be created into collection if supply the  createdocs argument.
num = 6000
# the num of search in batch
batchnum = 1000

if FileTest.exist?(randfile_name) then
    puts "test: reading Content File ===="
    i_randfile = File.new(randfile_name, "r")
    randlines = i_randfile.readlines
else
    puts "no rand Content File found."
    exit
end

need_create = false
if ARGV.length > 0 then
    if ARGV[0] == "createdocs" then
        need_create = true
    end
end

if need_create then
# batch create the documents
#
idbase = 10000000

puts "test: creating documents in batch ====="
while num > 0 do
    randnum = rand(idbase + num)
    sf1.call "documents/create",
    :collection => collectionName,
    :resource => {
        :DOCID => "#{idbase + randnum}",
        :DATE => "#{Time.now}",
        :Content => "testContent#{randlines[randnum % (randlines.size - 10), 10]}",
        :URL => "www.google.com/#{randnum}",
        :Title => "testTitle#{randlines[randnum % randlines.size]}"[0, 20 + randnum % 30],
    }
    num = num - 1
end

# reindex the documents
#
puts "reindex documents====="
puts sf1.call("commands/index", :collection => collectionName )
puts sf1.call("commands/optimize_index", :collection => collectionName )

end # end of create documents

# do batch search test
#
idbase = 10000
puts "test: searching documents in batch ====="
allkeywords = []
while batchnum > 0 do 
    randnum = rand(idbase)
    allkeywords.push("#{randlines[randnum % randlines.size]}"[0, 4 + randnum % 12])
    batchnum = batchnum.pred
end
response = sf1.batch do
     allkeywords.each do |keyword|
        begin
        sf1.call "documents/search",
        :collection => collectionName,
        :search => {
            :keywords => keyword
        },
        :header => {
            :check_time => true,
        }
        end
    end
end

out_file_path = "./batchSearchResult/batchSearch-Result-" + "#{Time.now.to_i}"
fs = File.open(out_file_path, "w")
if response then
    fs.write JSON.pretty_generate response
else
    puts "no response for batch search."
end

