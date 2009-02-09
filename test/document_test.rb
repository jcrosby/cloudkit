require 'helper'
DataMapper.setup(:default, 'sqlite3::memory:')
DataMapper.auto_migrate!

class DocumentTest < Test::Unit::TestCase

  context "A Document" do

    setup do
      @document = CloudKit::Document.new(:uri => "/items/123")
      @document.save
    end

    teardown do
      CloudKit::Document.all.destroy!
    end

    should "generate its ETag" do
      assert_not_nil @document.etag
      assert_not_equal '', @document.etag
    end

    should "set its Last-Modified property" do
      assert_not_nil @document.last_modified
      assert_not_equal '', @document.last_modified
    end

    should "have a unique URI" do
      invalid_document = CloudKit::Document.new(:uri => "/items/123")
      assert !invalid_document.valid?
    end
  end
end
