

class ScdParser

  NOT_SCD = 0
  INSERT_SCD = 1
  UPDATE_SCD = 2
  DELETE_SCD = 3
  
  include Enumerable

  def initialize(file)
    @file = file
    @max_property_name_len = 20
    @property_name_regex = Regexp.new("^[A-Za-z]{1,#{@max_property_name_len}}$")
    
  end

  def self.scd_type(scd_file)
    return NOT_SCD unless File.file?(scd_file)
    filename = File.basename(scd_file, ".SCD")
    return NOT_SCD if filename.length()!=27
    type_str = filename[24]
    type = NOT_SCD
    if type_str=="I"
      type = INSERT_SCD
    elsif type_str=="U"
      type = UPDATE_SCD
    elsif type_str=="D"
      type = DELETE_SCD
    end
    
    type
  end

  def self.get_doc_count(scd_path)
    scd_list = get_scd_list(scd_path)
    count = 0
    scd_list.each do |scd|
      scount = `grep -c '<DOCID>' #{scd}`
      count += scount.to_i
    end
    
    count
  end

  def self.get_ud_doc_count(scd_path)
    scd_list = get_scd_list(scd_path)
    ucount = 0
    dcount = 0
    scd_list.each do |scd|
      type = scd_type(scd)
      scount = `grep -c '<DOCID>' #{scd}`
      count = scount.to_i
      if type==UPDATE_SCD
        ucount+=count
      elsif type==DELETE_SCD
        dcount+=count
      end
    end

    return ucount, dcount
  end

  def self.get_scd_list(path)
    scd_list = []
    if File.file?(path)
      if scd_type(path)!=NOT_SCD
        scd_list << path
      end
    elsif File.directory?(path)
      Dir.foreach(path) do |f|
        file = File.join(path, f)
        if scd_type(file)!=NOT_SCD
          scd_list << file
        end
      end
    end
    scd_list.sort!

    scd_list
  end
  
  def each
    doc = {}
    last_property_name = ""
    i_file = File.open(@file, "r")
    i_file.each_line do |line|
      line.strip!
      property_name = ""
      property_value = line
      if line.start_with? '<'
        right = line.index('>')
        if right!=nil
          right -= 1
          property_name = line[1..right]
          right += 2
          property_value = line[right..-1]
          if !property_name.match(@property_name_regex)
            property_name = ""
            property_value = line
          end
        end
#         if property_name.length==0
#           puts "WARNING line : #{line}"
#         end
      end
      if property_name == ""
        doc[last_property_name] += "\n"
        doc[last_property_name] += property_value
      else
        if property_name == 'DOCID'
          if doc.size>0 
            yield doc
            doc = {}
          end
        end
        doc[property_name] = property_value
        last_property_name = property_name
      end
    end #each line end
    if doc.size>0
      yield doc
    end
    i_file.close
  end
end

