require File.dirname(__FILE__) + '/spec_helper'

describe "A Resource" do

  before(:all) do
    CloudKit.setup_storage_adapter unless CloudKit.storage_adapter
  end

  after(:each) do
    CloudKit.storage_adapter.clear
  end

  describe "on initialization" do

    before(:each) do
      @resource = CloudKit::Resource.new(
        CloudKit::URI.new('/items/123'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
    end

    it "should know its uri" do
      @resource.uri.string.should == CloudKit::URI.new('/items/123').string
    end

    it "should know its json" do
      @resource.json.should == "{\"foo\":\"bar\"}"
    end

    it "should know its remote user" do
      @resource.remote_user.should == 'http://eric.dolphy.info'
    end

    it "should default its deleted status to false" do
      @resource.should_not be_deleted
    end

    it "should default its archived status to false" do
      @resource.should_not be_archived
    end

    it "should default its etag to nil" do
      @resource.etag.should be_nil
    end

    it "should default its last-modified date to nil" do
      @resource.last_modified.should be_nil
    end

    it "should know if it is current" do
      @resource.should be_current
    end

  end

  describe "on save" do

    before(:each) do
      @resource = CloudKit::Resource.new(
        CloudKit::URI.new('/items/123'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
      @resource.save
    end

    it "should set its etag" do
      @resource.etag.should_not be_nil
    end

    it "should set its last modified date" do
      @resource.last_modified.should_not be_nil
    end

    it "should adjust its URI when adding to a resource collection" do
      resource = CloudKit::Resource.new(
        CloudKit::URI.new('/items'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
      resource.save
      resource.uri.string.should_not == '/items'
    end

    it "should flatten its json structure for querying" do
      hash = CloudKit.storage_adapter.query.first
      JSON(hash['json']).keys.include?('foo').should be_true
    end

    it "should know it is current" do
      @resource.should be_current
    end

  end

  describe "on create" do

    def store_json(hash)
      CloudKit::Resource.create(
        CloudKit::URI.new('/items/123'),
        JSON.generate(hash),
        'http://eric.dolphy.info')
      CloudKit.storage_adapter.query { |q|
        q.add_condition 'uri', :eql, '/items/123'
      }
    end

    it "should save the resource" do
      result = store_json({:foo => 'bar'})
      result.size.should == 1
      result.first['json'].should == "{\"foo\":\"bar\"}"
    end

    it "should accept nested array values" do
      result = store_json({:foo => [1,2]})
      result.size.should == 1
      result.first['json'].should == '{"foo":[1,2]}'
    end

    it "should accept nested hash values" do
      result = store_json({:foo => {:bar => 'baz'}})
      result.size.should == 1
      result.first['json'].should == '{"foo":{"bar":"baz"}}'
    end

    it "should accept recursively nested array/hash values" do
      result = store_json({:foo => [1,{:bar => [2,3]}]})
      result.size.should == 1
      result.first['json'].should == '{"foo":[1,{"bar":[2,3]}]}'
    end

  end

  describe "on update" do

    before(:each) do
      @resource = CloudKit::Resource.create(
        CloudKit::URI.new('/items/123'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
      @original_resource = @resource.dup
      now = Time.now
      Time.stub!(:now).and_return(now+1)
      @resource.update(JSON.generate({:foo => 'baz'}))
    end

    it "should version the resource" do
      @resource.versions.size.should == 2
      @resource.versions[-1].should be_archived
    end

    it "should set a new etag" do
      @resource.etag.should_not == @original_resource.etag
    end

    it "should set a new last modified date" do
      @resource.last_modified.should_not == @original_resource.last_modified
    end

    it "should fail on archived resource versions" do
      lambda {
        @resource.versions[-1].update({:foo => 'box'})
      }.should raise_error(CloudKit::HistoricalIntegrityViolation)
    end

    it "should fail on deleted resource versions" do
      lambda {
        @resource.delete
        @resource.update({:foo => 'box'})
      }.should raise_error(CloudKit::HistoricalIntegrityViolation)
    end

  end

  describe "on delete" do

    before(:each) do
      @resource = CloudKit::Resource.create(
        CloudKit::URI.new('/items/123'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
      now = Time.now
      Time.stub!(:now).and_return(now+1)
      @resource.delete
    end

    it "should version the resource" do
      @resource.versions.size.should == 2
      @resource.versions[-1].should be_archived
    end

    it "should set the etag on the main resource to nil" do
      @resource.etag.should be_nil
    end

    it "should know it has been deleted" do
      @resource.deleted?.should be_true
    end

    it "should fail on archived resource versions" do
      lambda {
        @resource.versions[-1].update({:foo => 'box'})
      }.should raise_error(CloudKit::HistoricalIntegrityViolation)
    end

  end

  describe "with versions" do

    before(:each) do
      @resource = CloudKit::Resource.create(
        CloudKit::URI.new('/items/123'),
        JSON.generate({:foo => 'bar'}),
        'http://eric.dolphy.info')
      @resource_list = [@resource.dup]

      2.times { |i|
        now = Time.now
        Time.stub!(:now).and_return(now+1)
        @resource.update(JSON.generate({:foo => i}))
        @resource_list << @resource.dup
      }
      @resource_list.reverse!
    end

    it "should keep an ordered list of versions" do
      @resource.versions.map { |version| version.last_modified }.
        should == @resource_list.map { |version| version.last_modified }
    end

    it "should include the current version in the version list" do
      current_ts = @resource.last_modified
      @resource_list.map { |version| version.last_modified }.should include(current_ts)
    end

    it "should know its previous version" do
      @resource.previous_version.last_modified.should == @resource_list[1].last_modified
    end

    it "should know its previous versions" do
      expected_times = @resource_list[1..-1].map { |version| version.last_modified }
      @resource.previous_versions.map { |version| version.last_modified }.should == expected_times
    end

  end

  describe "when finding" do

    before(:each) do
      ['bar', 'baz'].each do |value|
        CloudKit::Resource.create(
          CloudKit::URI.new('/items'),
          JSON.generate({:foo => value}),
          "http://eric.dolphy.info/#{value}_user")
      end
      CloudKit::Resource.create(
        CloudKit::URI.new('/items'),
        JSON.generate({:foo => 'box'}),
        "http://eric.dolphy.info/bar_user")
    end

    describe "using #all" do

      it "should find matching resources" do
        result = CloudKit::Resource.all(
          :remote_user => 'http://eric.dolphy.info/bar_user')
        result.size.should == 2
        result.map { |item| item.remote_user.should == 'http://eric.dolphy.info/bar_user' }
      end

      it "should return all elements if no restrictions are given" do 
        CloudKit::Resource.all.size.should == 3
      end

      it "should return an empty array if no resources are found" do
        CloudKit::Resource.all(:uri => 'fail').should be_empty
      end

      it "should find with query parameters referencing JSON elements" do
        resources = CloudKit::Resource.all(
          :collection_reference => '/items',
          :search => { :foo => 'bar' } )
        resources.size.should == 1
        resources.first.json.should == "{\"foo\":\"bar\"}"
      end

    end

    describe "on #first" do

      it "should find the first matching resource" do
        result = CloudKit::Resource.first(:remote_user => 'http://eric.dolphy.info/bar_user')
        result.should_not === Array
        result.remote_user.should == 'http://eric.dolphy.info/bar_user'
        result.parsed_json['foo'].should == 'box' # all listings are reverse ordered
      end

    end

    describe "on #current" do

      it "should find only current matching resources" do
        resource = CloudKit::Resource.first(:remote_user => 'http://eric.dolphy.info/bar_user')
        resource.update(JSON.generate({:foo => 'x'}))
        CloudKit::Resource.current(:collection_reference => '/items').size.should == 3
      end

    end

  end

end
