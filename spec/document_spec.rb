require File.dirname(__FILE__) + '/spec_helper'
DataMapper.setup(:default, 'sqlite3::memory:')
DataMapper.auto_migrate!

describe "A Document" do

  before(:each) do
    @document = CloudKit::Document.new(:uri => "/items/123")
    @document.save
  end

  after(:each) do
    CloudKit::Document.all.destroy!
  end

  it "should generate its ETag" do
    @document.etag.should_not be_nil
    @document.etag.should_not == ''
  end

  it "should set its Last-Modified property" do
    @document.last_modified.should_not be_nil
    @document.last_modified.should_not == ''
  end

  it "should have a unique URI" do
    invalid_document = CloudKit::Document.new(:uri => "/items/123")
    invalid_document.should_not be_valid
  end

end
