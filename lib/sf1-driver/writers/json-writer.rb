#---
# Author::  Ian Yang
# Created:: <2010-06-12 17:14:39>
#+++
#
# write data into JSON

require 'json'

module Sf1Driver
  module JsonWriter
    def writer_serialize(object)
      return JSON.dump(object)
    end
  end
end
