$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'rufus/tokyo/tyrant' # gem install rufus-tokyo
# start Tokyo Tyrant with a table store...
# ttserver data.tct
CloudKit.setup_storage_adapter(Rufus::Tokyo::TyrantTable.new('127.0.0.1', 1978))
use Rack::Session::Pool
use CloudKit::OAuthFilter
use CloudKit::OpenIDFilter
use CloudKit::Service, :collections => [:notes]
run lambda{|env| [200, {'Content-Type' => 'text/html', 'Content-Length' => '5'}, ['HELLO']]}
