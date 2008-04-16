$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift File.expand_path(File.dirname(__FILE__) + '/cloudkit')
require 'rubygems'
gem 'ruby-openid', '>=2.0.4'
gem 'activerecord', '>=2.0.2'
gem 'rack', '>=0.3.0'
require 'rack'
require 'activerecord'
require 'openid'
require 'openid/util'
require 'auth'
require 'gwt'