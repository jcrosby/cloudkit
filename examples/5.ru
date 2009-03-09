$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
CloudKit.setup_storage_adapter(Rufus::Tokyo::Table.new('cloudkit.tdb'))
use Rack::Session::Pool
use CloudKit::OAuthFilter
use CloudKit::OpenIDFilter
use CloudKit::Service, :collections => [:notes]
run lambda{|env| [200, {'Content-Type' => 'text/html', 'Content-Length' => '5'}, ['HELLO']]}
