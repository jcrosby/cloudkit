begin
  require File.expand_path('.bundle/environment', __FILE__)
rescue LoadError
  require 'rubygems'
  require 'bundler'
  Bundler.setup
end

Bundler.require
require File.expand_path(File.join(File.dirname(__FILE__), 'lib', '<%= @app_name %>'))

use Rack::Static, :urls => ["/css", "/img", "/js"], :root => "public"
run <%= @app_name.capitalize %>.app
