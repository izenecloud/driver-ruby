require 'logger'

module Sf1Logger
  
  def self.included base
    if $sf1_logger.nil?
      $sf1_logger = Logger.new(STDERR)
    end
  end

  def puts str
    $sf1_logger.info str
  end
end

