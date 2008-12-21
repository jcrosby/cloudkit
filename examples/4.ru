$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
use CloudKit::OAuthFilter
use CloudKit::Service, :collections => [:notes]
run lambda{|env| [200, {}, ['HELLO']]}
