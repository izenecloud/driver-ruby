
class HdfsHelper
  def self.get_index_path(scd_path)
    p = scd_path.index('sf1r_scds')
    return nil if p.nil?
    return "/#{scd_path[p..-1]}"
  end
end
