require_relative 'scd_parser'
require_relative 'scd_writer'
class ScdTypeWriter
  
  def initialize(dir)
    @dir = dir
    @writers = {}
    @type_map = {ScdParser::INSERT_SCD => 'I', ScdParser::UPDATE_SCD => 'U', ScdParser::RTYPE_SCD => 'R', ScdParser::DELETE_SCD => 'D'}
  end
  
  def append(doc, type)
    writer = get_writer(type)
    return if writer.nil?
    writer.append(doc)
  end
  
  def close
    @writers.each_value do |writer|
      writer.close
    end
  end

  private
  def get_writer(type)
    return nil if type==ScdParser::NOT_SCD
    writer = @writers[type]
    if writer.nil?
      t = @type_map[type]
      writer = ScdWriter.new(@dir, t)
      @writers[type] = writer
    end
    return writer
  end
  
end
