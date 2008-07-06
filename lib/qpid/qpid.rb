# # stdlib requires
# require 'rubygems'
# 
# # 3rd party rubygem requires
# 
# # powerset rubygem requires
# 
# $:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed
# 
# # internal requires
# # require 'qpid/filename_without_rb'
# require "qpid/client"
# require "qpid/queue"
# require "qpid/codec"
# require "qpid/connection"
# require "qpid/peer"
# require "qpid/spec"
# 
# # gem version
# # KEEP THE VERSION CONSTANT BELOW THIS COMMENT
# # IT IS AUTOMATICALLY UPDATED FROM THE VERSION
# # SPECIFIED IN configure.ac DURING PACKAGING
# 
# module Powerset
#   class Qpid
#     VERSION = '0.0.4'
#     
#     class <<self
#       def load_spec(version)
#         spec = Spec.load(File.join(File.dirname(__FILE__), "../specs/#{version}.xml"))
#       end
#     end
#   end
# end
