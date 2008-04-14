$:.unshift '.'
require 'sinatra'

Sinatra::Application.default_options.merge!(
  :run => false,
  :env => 'development'
)

use Rack::Session::Pool, :key => 'rack.session',
  :path => '/',
  :expire_after => 2592000
  
require 'app'

run Sinatra.application
