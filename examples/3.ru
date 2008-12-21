$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
use Rack::Session::Pool
use CloudKit::OpenIDFilter
use CloudKit::Service, :collections => [:notes]
run lambda{|env| [200, {}, ['HELLO']]}
