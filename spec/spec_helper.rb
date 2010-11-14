$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'rexml/document'

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

module Rack
  class Config
    def initialize(app, &block)
      @app = app
      @block = block
    end

    def call(env)
      @block.call(env)
      @app.call(env)
    end
  end
end

shared_examples_for "a CloudKit storage adapter" do
  it "which should reject non-hash records" do
    @table['a'] = 1
    @table['a'].should be_nil
  end

  it "which should reject non-string record keys" do
    @table['a'] = {:foo => 'bar'}
    @table['a'].should be_nil
  end

  it "which should reject non-string record values" do
    @table['a'] = {'foo' => 1}
    @table['a'].should be_nil
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

end
