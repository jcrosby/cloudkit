$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift File.expand_path(File.dirname(__FILE__) + '/cloudkit')
require 'rubygems'
gem 'activerecord', '>=2.1.0'
gem 'ruby-openid', '>=2.0.4'
gem 'rack', '>=0.3.0'
require 'rack'
require 'activerecord'
require 'openid'
require 'openid/util'
require 'auth'
require 'gwt'
require 'air'

require "qpid/client"
require "qpid/queue"
require "qpid/codec"
require "qpid/connection"
require "qpid/peer"
require "qpid/spec"
