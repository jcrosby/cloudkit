require File.dirname(__FILE__) + '/spec_helper'

describe "A URI" do

  it "should know its string form" do
    CloudKit::URI.new('/items/123').string.should == '/items/123'
  end

  it "should encode urls with spaces in them" do
    CloudKit::URI.new('/items/1 2 3').string.should == '/items/1%202%203'
  end

  it "should know its parent resource collection" do
    ['/items', '/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).collection_uri_fragment.should == '/items'
    }
  end

  it "should split itself into components" do
    CloudKit::URI.new('/items/123/versions/abc').components.should == ['items', '123', 'versions', 'abc']
  end

  it "should know its collection type" do
    ['/items', '/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).collection_type.should == :items
    }
  end

  it "should know the URI of its current version" do
    ['/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).current_resource_uri.should == '/items/123'
    }
  end

  it "should know if it is a meta URI" do
    ['/items', '/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_meta_uri
    }
    CloudKit::URI.new('/cloudkit-meta').should be_meta_uri
  end

  it "should know if it is a resource collection URI" do
    ['/cloudkit-meta', '/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_resource_collection_uri
    }
    CloudKit::URI.new('/items').should be_resource_collection_uri
  end

  it "should know if it is a resolved resource collection URI" do
    ['/items', '/items/123', '/items/123/versions', '/items/123/versions/_resolved', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_resolved_resource_collection_uri
    }
    CloudKit::URI.new('/items/_resolved').should be_resolved_resource_collection_uri
  end

  it "should know if it is a resource URI" do
    ['/items', '/items/_resolved', '/items/123/versions', '/items/123/versions/_resolved', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_resource_uri
    }
    CloudKit::URI.new('/items/123').should be_resource_uri
  end

  it "should know if it is a version collection URI" do
    ['/items', '/items/_resolved', '/items/123', '/items/123/versions/_resolved', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_version_collection_uri
    }
    CloudKit::URI.new('/items/123/versions').should be_version_collection_uri
  end

  it "should know if it is a resolved version collection URI" do
    ['/items', '/items/_resolved', '/items/123', '/items/123/versions', '/items/123/versions/abc'].each { |uri|
      CloudKit::URI.new(uri).should_not be_resolved_version_collection_uri
    }
    CloudKit::URI.new('/items/123/versions/_resolved').should be_resolved_version_collection_uri
  end

  it "should know if it is a resource version URI" do
    ['/items', '/items/_resolved', '/items/123', '/items/123/versions', '/items/123/versions/_resolved'].each { |uri|
      CloudKit::URI.new(uri).should_not be_resource_version_uri
    }
    CloudKit::URI.new('/items/123/versions/abc').should be_resource_version_uri
  end

  it "should know its cannonical URI string" do
    CloudKit::URI.new('/items/123').cannonical_uri_string.should == '/items/123'
  end

  it "should generate its cannonical URI string when needed" do
    CloudKit::URI.new('/items').cannonical_uri_string.should match(/\/items\/.+/)
  end

  it "should fail when attempting to generate a cannonical URI string for versioned resources" do
    lambda {
      CloudKit::URI.new('/items/123/versions/abc').cannonical_uri_string
    }.should raise_error(CloudKit::InvalidURIFormat)
  end
end
