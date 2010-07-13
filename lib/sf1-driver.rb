#---
# Author::  Ian Yang
# Created:: <2010-07-13 15:10:37>
#+++
#
# 
class Sf1Driver
  VERSION = "2.0.0"

  # Max sequence number. It is also the upper limit of the number of requests
  # in a batch request.
  #
  # max(int32) - 1
  MAX_SEQUENCE = (1 << 31) - 2
end
