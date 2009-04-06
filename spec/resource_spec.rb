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
      hash.keys.include?('foo').should be_true
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
      ['bar', 'baz'].each_with_index do |value, index|
        CloudKit::Resource.create(
          CloudKit::URI.new('/items'),
          JSON.generate({:foo => value, :rating => index}),
          "http://eric.dolphy.info/#{value}_user")
      end
      CloudKit::Resource.create(
        CloudKit::URI.new('/items'),
        JSON.generate({:foo => 'box', :rating => 2}),
        "http://eric.dolphy.info/bar_user")
    end

    describe "using JSONQuery" do

      it "should require a matcher" do
        lambda {
          CloudKit::Resource.query(:collection_reference => '/items')
        }.should raise_error(CloudKit::InvalidQueryException)
      end

      it "should sort ascending" do
        pending
        # /items/[/rating]
      end

      it "should sort descending" do
        pending
        # /items/[\rating]
      end

      it "should sort using subsorts" do
        pending
        # /items/[\rating, \duration]
      end

      it "should sort using mixed subsorts" do
        pending
        # /items/[\rating, /duration]
        # /items/[/rating, \duration]
      end

      it "should extract property values" do
        pending
        # /items/[=foo]
      end

      it "should extract property values and evaluate them in the context of their extractor" do
        pending
        # /customers/[={name:firstName + ' ' + lastName, address: street + state}]
      end

      it "should understand recursive decent finders" do
        pending
        # /items/objectid..name # uris == ids. objectid -> uri in the case of CloudKit.
      end

      it "should find using the object id literal syntax" do
        # consider that /items/33 can just be the URI and not interpreted as a collection/id
        pending
        # /items/?bestReview=/items/33
      end

      it "should interpret comma-delimited expressions as unions" do
        pending
        # [expr, expr]
      end

      it "should assume an outer [] if none exist"

      it "should allow chaining of queries using multiple [] blocks"

      describe "with array operations" do

        it "should limit using a range" do
          pending
          # /items/[0:10]
        end

        it "should limit using a range while honoring a step number" do
          pending
          # /items/[0:10:2]
        end

      end

      describe "with JavaScript operators" do

        it "should match using =" do
          # /items/?foo=bar
          # This is the single exception in JSONQuery around JavaScript operators.
          # In the case of equality checks, = is used instead of ==
          result = CloudKit::Resource.query(
            :collection_reference => '/items',
            :match                => '?foo=bar')
          result.size.should == 1
          result.first.parsed_json['foo'].should == 'bar'
        end

        it "should match using + in a value" do
          # /items/?rating=3+0
          pending
        end

        it "should match using + in a path" do
          # /items/?rating+id=3
          pending
        end

        it "should match using - in a value" do
          # /items/?rating=3-1
          pending
        end

        it "should match using - in a path" do
          # /items/?rating-1=2
          pending
        end

        it "should match using / in a value" do
          # /items/?rating=4/2
          pending
        end

        it "should match using / in a path" do
          # /items/?rating/2=2
          pending
        end

        it "should match using * in a value" do
          # /items/?rating=2*1
          pending
        end

        it "should match using * in a path" do
          # /items/?rating*2=4
          pending
        end

        it "should match using &"

        it "should match using |"

        it "should match using %"

        it "should match using ( and )"

        it "should find using <" do
          # /items/?rating<3
          4.times { |index|
            result = CloudKit::Resource.query(
              :collection_reference => '/items',
              :match                => "?rating<#{index}")
            result.size.should == index
          }
        end

        it "should find using >" do
          # /items/?rating>3
          3.times { |index|
            result = CloudKit::Resource.query(
              :collection_reference => '/items',
              :match                => "?rating>#{index}")
            result.size.should == (index-2).abs
          }
        end

        it "should match using <=" do
          # /items/?rating<=3
          3.times { |index|
            result = CloudKit::Resource.query(
              :collection_reference => '/items',
              :match                => "?rating<=#{index}")
            result.size.should == index+1
          }
          result = CloudKit::Resource.query(
            :collection_reference => '/items',
            :match                => '?rating<=-1')
          result.size.should == 0
        end

        it "should match using >=" do
          # /items/?rating>=3
          result = CloudKit::Resource.query(
            :collection_reference => '/items',
            :match                => '?rating>=3')
          result.size.should == 0
          3.times { |index|
            result = CloudKit::Resource.query(
              :collection_reference => '/items',
              :match                => "?rating>=#{index}")
            result.size.should == (index-3).abs
          }
        end

        it "should match using !=" do
          # /items?rating!=2
          3.times { |index|
            result = CloudKit::Resource.query(
              :collection_reference => '/items',
              :match                => "?rating!=#{index}")
            result.size.should == 2
          }
        end

      end

      describe "with a date function" do

        it "should understand ISO date strings" do
          pending
          # date("Sat, 07 Feb 2009 22:51:26 GMT")
        end

        it "should understand epoch seconds" do
          pending
          # date(1234047109376)
        end

      end

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
          :foo                  => 'bar')
        resources.size.should == 1
        resources.first.parsed_json.should == {'foo' => 'bar', 'rating' => 0}
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
