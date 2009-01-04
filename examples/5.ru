$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
use Rack::Config do |env|
  env[CLOUDKIT_STORAGE_URI] = 'sqlite://example.db'
end
use Rack::Session::Pool
use CloudKit::OAuthFilter
use CloudKit::OpenIDFilter
use CloudKit::Service, :collections => [:notes]
run lambda{|env| [200, {'Content-Type' => 'text/html'}, ['HELLO']]}
