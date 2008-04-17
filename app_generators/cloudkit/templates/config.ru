$:.unshift '.'
require 'sinatra'
require 'json'
require 'yaml'
require 'erb'
require 'active_record'
require 'cloudkit'

Sinatra::Application.default_options.merge!(
  :run => false,
  :env => 'development'
)

use Rack::Session::Pool, :key => 'rack.session',
  :path => '/',
  :expire_after => 2592000
  
require 'app'
require 'resources'

run Sinatra.application
