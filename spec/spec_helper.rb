$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'rexml/document'
require 'rack/test'

require 'support/fixtures'

TEST_REMOTE_USER = '/cloudkit_users/abcdef'.freeze
VALID_TEST_AUTH = {CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER}.freeze

def echo_text(text)
  lambda {|env| [200, app_headers(text), [text]]}
end

def echo_env(key)
  lambda {|env| [200, app_headers(env[key] || ''), [env[key] || '']]}
end

def app_headers(content)
  {'Content-Type' => 'text/html', 'Content-Length' => content.length.to_s}
end

#module Rack
#  class Config
#    def initialize(app, &block)
#      @app = app
#      @block = block
#    end
#
#    def call(env)
#      @block.call(env)
#      @app.call(env)
#    end
#  end
#end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  def app
    CloudKit.setup_storage_adapter
    Rack::Builder.app do |builder|
      expose *CloudKit::Fixtures.collections
    end
    #CloudKit::Server.app
  end

  def json_body
    JSON.parse(subject.body)
  end

  #conf.before(:each) do
  #  CloudKit.storage_adapter.clear
  #end

end

shared_examples_for "it was successful" do
  its(:status) { should satisfy { |status| [200, 201].include?(status)} }
end

shared_examples_for "it should have the proper update response structure" do

  it "should have the right structure" do
    json_body.keys.sort.should == ["etag", "last_modified", "ok", "uri"]
    json_body["ok"].should == true
    json_body["etag"].should_not be_empty
    json_body["uri"].should_not be_empty
    json_body["last_modified"].should_not be_empty
  end
end

shared_examples_for "it should have the proper creation response structure" do

  it_should_behave_like "it should have the proper update response structure"

  its(:headers) { should include("Location") }
end

shared_examples_for "it has uris" do

  it "should have an items object" do
    json_body.should include('uris')
  end

  it "should have at least one uri" do
    json_body['uris'].should have_at_least(1).uri
  end
end

shared_examples_for "it's response is json encoded" do

  it "has the correct Content-Type header" do
    subject.headers["Content-Type"].should == "application/json"
  end

  it "body should be parsable JSON" do
    expect {
      json_body
    }.to_not raise_exception(JSON::ParserError)
  end
end

shared_examples_for "a CloudKit storage adapter" do
  it "which should reject non-hash records" do
    expect {
      @table['a'] = 1
    }.to
  end

  it "which should reject non-string record keys" do
    expect {
      @table['a'] = {:foo => 'bar'}
    }.to raise_error(CloudKit::InvalidRecord)
  end

  it "which should reject non-string record values" do
    expect {
      @table['a'] = {'foo' => 1}
    }.to raise_error(CloudKit::InvalidRecord)
  end

  it "which should get and set values for table keys like a hash" do
    @table['a'] = {'foo' => 'bar'}
    @table['a'].should == {'foo' => 'bar'}
  end

  it "which should clear its contents" do
    @table['a'] = {'foo' => 'bar'}
    @table['b'] = {'foo' => 'baz'}
    @table.clear
    @table['a'].should be_nil
    @table['b'].should be_nil
    @table.keys.should be_empty
  end

  it "which should keep an ordered set of keys" do
    pending "is an ordered set of keys really necessary or is this a hold over from TokyoCabinet"
    @table['b'] = {'foo' => 'bar'}
    @table['a'] = {'foo' => 'baz'}
    @table.keys.should == ['b', 'a']
  end

  it "which should generate incrementing ids" do
    pending "is it important that the keys increment? Or is it okay that they are unique?"
    ids = []
    4.times { ids << @table.generate_unique_id }
    ids.should == [1, 2, 3, 4]
  end

  it "which should query using a block supporting :eql comparisons" do
    # For this release, only :eql comparisons are required
    @table['a'] = {'foo' => 'bar', 'color' => 'blue'}
    @table['b'] = {'foo' => 'baz', 'color' => 'blue'}
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
    }.should == [{'foo' => 'bar', 'color' => 'blue', :pk => 'a'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'baz')
    }.should == [{'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
    @table.query { |q|
      q.add_condition('color', :eql, 'blue')
    }.should == [
      {'foo' => 'bar', 'color' => 'blue', :pk => 'a'},
      {'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
      q.add_condition('color', :eql, 'blue')
    }.should == [{'foo' => 'bar', 'color' => 'blue', :pk => 'a'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
      q.add_condition('color', :eql, 'red')
    }.should == []
  end

  it "which should query without a block" do
    @table['a'] = {'foo' => 'bar', 'color' => 'blue'}
    @table['b'] = {'foo' => 'baz', 'color' => 'blue'}
    @table.query.should == [
      {'foo' => 'bar', 'color' => 'blue', :pk => 'a'},
      {'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
  end

  context "with a json sub document" do
    it "should be able to search for items using a json query" do
      @table['a'] = {'foo' => 'bar', 'json' => {'letter' => 'a'}.to_json}
      @table['b'] = {'foo' => 'bar', 'json' => {'letter' => 'b'}.to_json}
      @table.query { |q|
        q.add_condition('search', :eql, {'letter' => 'a'}.to_json )
      }.should == [{"json" => "{\"letter\":\"a\"}", "foo" => "bar", :pk => "a"}]
    end

    it "should query for items nested in hashes in sub arrays" do
      @table['white'] = { 'json' => { 'name' => 'white', 'composition' => [{'red' => '255'},{'blue' => '255'},{'green' => '255'}] }.to_json }
      @table['black'] = { 'json' => { 'name' => 'black', 'composition' => [{'red' => '0'},{'blue' => '0'},{'green' => '0'}] }.to_json }
      @table['red'] = { 'json' => { 'name' => 'red', 'composition' => [{'red' => '255'},{'blue' => '0'},{'green' => '0'}] }.to_json }
      @table['green'] = { 'json' => { 'name' => 'green', 'composition' => [{'red' => '0'},{'blue' => '0'},{'green' => '255'}] }.to_json }
      @table['blue'] = { 'json' => { 'name' => 'blue', 'composition' => [{'red' => '0'},{'blue' => '255'},{'green' => '0'}] }.to_json }
      @table.query { |q|
        q.add_condition('search',:eql,{'composition.red' => '0'}.to_json)
      }.should == [{"json"=>"{\"name\":\"black\",\"composition\":[{\"red\":\"0\"},{\"blue\":\"0\"},{\"green\":\"0\"}]}", :pk=>"black"},
                   {"json"=>"{\"name\":\"green\",\"composition\":[{\"red\":\"0\"},{\"blue\":\"0\"},{\"green\":\"255\"}]}", :pk=>"green"},
                   {"json"=>"{\"name\":\"blue\",\"composition\":[{\"red\":\"0\"},{\"blue\":\"255\"},{\"green\":\"0\"}]}", :pk=>"blue"}]
    end

    it "should query for items nested in hashes in sub arrays in hashes in sub arrays" do
      @table["one"] = {'json' => { 'services' => [ {'nodes' => [ {'name' => 'one'},{'name' => 'two'} ] } ] }.to_json }
      @table["two"] = {'json' => { 'services' => [ {'nodes' => [ {'name' => 'three'},{'name' => 'four'} ] } ] }.to_json }
      @table["three"] = {'json' => { 'services' => [ {'nodes' => [ 0 ,'bang' ] } ] }.to_json }
      @table.query { |q|
        q.add_condition('search', :eql, {'services.nodes.name' => 'three'}.to_json)
      }.should == [{:pk=>"two", "json"=>"{\"services\":[{\"nodes\":[{\"name\":\"three\"},{\"name\":\"four\"}]}]}"}]
    end

    it "should query for a full sub item match" do
      @table["one"] = {'json' => { 'services' => [ {'nodes' => [ {'name' => 'one', 'kind' => 'good'},{'name' => 'two','kind' => 'bad'} ] } ] }.to_json }
      @table["two"] = {'json' => { 'services' => [ {'nodes' => [ {'name' => 'one', 'kind' => 'bad'},{'name' => 'four'} ] } ] }.to_json }
      @table.query { |q|
        q.add_condition("search", :eql, {"services[].nodes[]" => {"name" => "one", "kind" => "bad"}}.to_json)
      }.map {|r| r.update("json" => JSON.parse(r["json"])) }.
        should == [{:pk=>"two", "json"=>JSON.parse("{\"services\":[{\"nodes\":[{\"kind\":\"bad\",\"name\":\"one\"},{\"name\":\"four\"}]}]}")}]
    end
  end

end
