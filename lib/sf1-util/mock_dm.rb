# encoding: UTF-8
require_relative 'scd_parser'
class MockDm

  attr_reader :docs, :count
  attr_accessor :name

  def initialize(index_keys = [])
    @docs = []
    @idmap = {}
    @index_map = {}
    index_keys.each do |key|
      @index_map[key] = {}
    end
    @count = 0
    @name = ""
  end


  def insert(doc)
    docid = doc[:DOCID]
    return false if docid.nil?
    return false if @idmap.has_key?(docid)
    index = @docs.size
    @idmap[docid] = index
    id = index+1
    doc[:_id] = id

    @index_map.each_pair do |k, index|
      v = doc[k]
      next if v.nil?
      update_index(index, id, nil, v)
    end

    @docs << doc.clone
    @count += 1

    true
  end

  def update(doc)
    docid = doc[:DOCID]
    return false if docid.nil?
    index = @idmap[docid]
    if index.nil?
      return insert(doc) #same with sf1r logic
    else
      exist_doc = @docs[index]
      id = exist_doc[:_id]
      @index_map.each_pair do |k, index|
        v = doc[k]
        next if v.nil?
        update_index(index, id, exist_doc[k], v)
      end
      exist_doc.merge!(doc)
    end

    true
  end

  #def iu(doc)
    #docid = doc[:DOCID]
    #return if docid.nil?
    #index = @idmap[docid]
    #if index.nil?
      #insert(doc)
    #else
      #update(doc)
    #end
  #end

  def delete(doc)
    docid = doc[:DOCID]
    return false if docid.nil?
    index = @idmap[docid]
    return false if index.nil?
    exist_doc = @docs[index]
    id = exist_doc[:_id]
    @index_map.each_pair do |k, index|
      oldv = exist_doc[k]
      next if oldv.nil?
      update_index(index, id, oldv, nil)
    end

    @docs[index] = nil
    @idmap.delete(docid)
    @count -= 1

    true
  end

  def index(path)
    scd_list = ScdParser.get_scd_list(path)
    return if scd_list.empty?
    puts "find #{scd_list.size} scd"
    scd_list.each do |scd|
      puts "indexing #{scd}"
      parser = ScdParser.new(scd)
      scd_type = ScdParser.scd_type(scd)
      parser.each do |doc|
        sdoc = {}
        doc.each_pair {|k,v| sdoc[k.to_sym] = v}
        if scd_type==ScdParser::INSERT_SCD
          insert(sdoc)
        elsif scd_type==ScdParser::UPDATE_SCD
          update(sdoc)
        elsif scd_type==ScdParser::DELETE_SCD
          delete(sdoc)
        end
      end
    end

  end

  def get(docid)
    if docid.is_a? String
      index = @idmap[docid]
    else
      index = docid-1
    end
    return nil if index.nil?

    @docs[index]
  end

  def search(key, value)
    index = @index_map[key]
    return [] if index.nil?
    posting = index[value]
    return [] if posting.nil?
    result = []
    posting.each do |docid|
      result << get(docid)
    end

    result
  end

  def clear
    @docs.clear
    @idmap.clear
    @index_map.each_pair do |k,v|
      v.clear
    end
    @count = 0
  end

  private
  def update_index(index, id, oldv, newv)
    unless oldv.nil?
      posting = index[oldv]
      unless posting.nil?
        posting.delete(id)
      end
    end
    unless newv.nil?
      posting = index[newv]
      unless posting.nil?
        posting << id
        posting.uniq!
      else
        index[newv] = [id]
      end
    end
  end

end
