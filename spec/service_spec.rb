require File.dirname(__FILE__) + '/spec_helper'

describe "A CloudKit::Service" do

  it "should return a 501 for unimplemented methods" do
    app = Rack::Builder.new {
      use Rack::Lint
      use CloudKit::Service, :collections => [:items, :things]
      run echo_text('martino')
    }

    response = Rack::MockRequest.new(app).request('TRACE', '/items')
    response.status.should == 501

    # disable Rack::Lint so that an invalid HTTP method
    # can be tested
    app = Rack::Builder.new {
      use CloudKit::Service, :collections => [:items, :things]
      run echo_text('nothing')
    }
    response = Rack::MockRequest.new(app).request('REJUXTAPOSE', '/items')
    response.status.should == 501
  end

  describe "using auth" do

    before(:each) do
      # mock an authenticated service in pieces
      mock_auth = Proc.new { |env|
        r = CloudKit::Request.new(env)
        r.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
      }
      inner_app = echo_text('martino')
      service = CloudKit::Service.new(
        inner_app, :collections => [:items, :things])
      CloudKit.setup_storage_adapter unless CloudKit.storage_adapter
      config = Rack::Config.new(service, &mock_auth)
      authed_service = Rack::Lint.new(config)
      @request = Rack::MockRequest.new(authed_service)
    end

    after(:each) do
      CloudKit.storage_adapter.clear
    end

    it "should allow requests for / to pass through" do
      response = @request.get('/')
      response.body.should == 'martino'
    end

    it "should allow any non-specified resource request to pass through" do
      response = @request.get('/hammers')
      response.body.should == 'martino'
    end

    it "should return a 500 if authentication is configured incorrectly" do
      # simulate auth requirement without CLOUDKIT_AUTH_KEY being set by the
      # auth filter(s)
      response = @request.get('/items')
      response.status.should == 500
    end

    describe "on GET /cloudkit-meta" do

      before(:each) do
        @response = @request.get('/cloudkit-meta', VALID_TEST_AUTH)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should return a list of hosted collection URIs" do
        uris = JSON.parse(@response.body)['uris']
        uris.sort.should == ['/items', '/things']
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag" do
        @response['ETag'].should_not be_nil
      end

      it "should not set a Last-Modified header" do
        @response['Last-Modified'].should be_nil
      end

    end

    describe "on GET /:collection" do

      before(:each) do
        3.times do |i|
          json = JSON.generate(:this => i.to_s)
          @request.put("/items/#{i}", {:input => json}.merge(VALID_TEST_AUTH))
        end
        json = JSON.generate(:this => '4')
        @request.put(
          '/items/4', {:input => json}.merge(CLOUDKIT_AUTH_KEY => 'someoneelse'))
        @response = @request.get(
          '/items', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
        @parsed_response = JSON.parse(@response.body)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should return a list of URIs for all owner-originated resources" do
        @parsed_response['uris'].sort.should == ['/items/0', '/items/1', '/items/2']
      end

      it "should sort descending on last_modified date" do
        @parsed_response['uris'].should == ['/items/2', '/items/1', '/items/0']
      end

      it "should return the total number of uris" do
        @parsed_response['total'].should_not be_nil
        @parsed_response['total'].should == 3
      end

      it "should return the offset" do
        @parsed_response['offset'].should_not be_nil
        @parsed_response['offset'].should == 0
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified date" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should accept a limit parameter" do
        response = @request.get('/items?limit=2', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == ['/items/2', '/items/1']
        parsed_response['total'].should == 3
      end

      it "should accept an offset parameter" do
        response = @request.get('/items?offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == ['/items/1', '/items/0']
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 3
      end

      it "should accept combined limit and offset parameters" do
        response = @request.get('/items?limit=1&offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == ['/items/1']
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 3
      end

      it "should return an empty list if no resources are found" do
        response = @request.get('/things', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == []
        parsed_response['total'].should == 0
        parsed_response['offset'].should == 0
      end

      it "should return a resolved link header" do
        @response['Link'].should_not be_nil
        @response['Link'].match("<http://example.org/items/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\"").should_not be_nil
      end

    end

    describe "on GET /:collection/_resolved" do

      before(:each) do
        3.times do |i|
          json = JSON.generate(:this => i.to_s)
          @request.put("/items/#{i}", {:input => json}.merge(VALID_TEST_AUTH))
        end
        json = JSON.generate(:this => '4')
        @request.put(
          '/items/4', {:input => json}.merge(CLOUDKIT_AUTH_KEY => 'someoneelse'))
        @response = @request.get(
          '/items/_resolved', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
        @parsed_response = JSON.parse(@response.body)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should return all owner-originated documents" do
        @parsed_response['documents'].map{|d| d['uri']}.sort.should == ['/items/0', '/items/1', '/items/2']
      end

      it "should sort descending on last_modified date" do
        @parsed_response['documents'].map{|d| d['uri']}.should == ['/items/2', '/items/1', '/items/0']
      end

      it "should return the total number of documents" do
        @parsed_response['total'].should_not be_nil
        @parsed_response['total'].should == 3
      end

      it "should return the offset" do
        @parsed_response['offset'].should_not be_nil
        @parsed_response['offset'].should == 0
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified date" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should accept a limit parameter" do
        response = @request.get('/items/_resolved?limit=2', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == ['/items/2', '/items/1']
        parsed_response['total'].should == 3
      end

      it "should accept an offset parameter" do
        response = @request.get('/items/_resolved?offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == ['/items/1', '/items/0']
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 3
      end

      it "should accept combined limit and offset parameters" do
        response = @request.get('/items/_resolved?limit=1&offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == ['/items/1']
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 3
      end

      it "should return an empty list if no documents are found" do
        response = @request.get('/things/_resolved', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].should == []
        parsed_response['total'].should == 0
        parsed_response['offset'].should == 0
      end

      it "should return an index link header" do
        @response['Link'].should_not be_nil
        @response['Link'].match("<http://example.org/items>; rel=\"index\"").should_not be_nil
      end

    end

    describe "on GET /:collection/:id" do

      before(:each) do
        json = JSON.generate(:this => 'that')
        @request.put('/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
        @response = @request.get(
          '/items/abc', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should return a document for valid owner-originated requests" do
        data = JSON.parse(@response.body)
        data['this'].should == 'that'
      end

      it "should return a 404 if a document does not exist" do
        response = @request.get('/items/nothing', VALID_TEST_AUTH)
        response.status.should == 404
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag header" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified header" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should not return documents for unauthorized users" do
        response = @request.get('/items/abc', CLOUDKIT_AUTH_KEY => 'bogus')
        response.status.should == 404
      end

      it "should return a versions link header" do
        @response['Link'].should_not be_nil
        @response['Link'].match("<http://example.org/items/abc/versions>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/versions\"").should_not be_nil
      end

    end

    describe "on GET /:collection/:id/versions" do

      before(:each) do
        @etags = []
        4.times do |i|
          json = JSON.generate(:this => i)
          options = {:input => json}.merge(VALID_TEST_AUTH)
          options.filter_merge!('HTTP_IF_MATCH' => @etags.try(:last))
          result = @request.put('/items/abc', options)
          @etags << JSON.parse(result.body)['etag']
        end
        @response = @request.get(
          '/items/abc/versions', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
        @parsed_response = JSON.parse(@response.body)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should be successful even if the current resource has been deleted" do
        @request.delete('/items/abc', {'HTTP_IF_MATCH' => @etags.last}.merge(VALID_TEST_AUTH))
        response = @request.get('/items/abc/versions', VALID_TEST_AUTH)
        @response.status.should == 200
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].size.should == 4
      end

      it "should return a list of URIs for all versions of a resource" do
        uris = @parsed_response['uris']
        uris.should_not be_nil
        uris.size.should == 4
      end

      it "should return a 404 if the resource does not exist" do
        response = @request.get('/items/nothing/versions', VALID_TEST_AUTH)
        response.status.should == 404
      end

      it "should return a 404 for non-owner-originated requests" do
        response = @request.get(
          '/items/abc/versions', CLOUDKIT_AUTH_KEY => 'someoneelse')
        response.status.should == 404
      end

      it "should sort descending on last_modified date" do
        @parsed_response['uris'].should == ['/items/abc'].concat(@etags[0..-2].reverse.map{|e| "/items/abc/versions/#{e}"})
      end

      it "should return the total number of uris" do
        @parsed_response['total'].should_not be_nil
        @parsed_response['total'].should == 4
      end

      it "should return the offset" do
        @parsed_response['offset'].should_not be_nil
        @parsed_response['offset'].should == 0
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified date" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should accept a limit parameter" do
        response = @request.get('/items/abc/versions?limit=2', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == ['/items/abc', "/items/abc/versions/#{@etags[-2]}"]
        parsed_response['total'].should == 4
      end

      it "should accept an offset parameter" do
        response = @request.get('/items/abc/versions?offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == @etags.reverse[1..-1].map{|e| "/items/abc/versions/#{e}"}
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 4
      end

      it "should accept combined limit and offset parameters" do
        response = @request.get('/items/abc/versions?limit=1&offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['uris'].should == ["/items/abc/versions/#{@etags[-2]}"]
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 4
      end

      it "should return a resolved link header" do
        @response['Link'].should_not be_nil
        @response['Link'].match("<http://example.org/items/abc/versions/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\"").should_not be_nil
      end

    end

    describe "on GET /:collections/:id/versions/_resolved" do

      before(:each) do
        @etags = []
        4.times do |i|
          json = JSON.generate(:this => i)
          options = {:input => json}.merge(VALID_TEST_AUTH)
          options.filter_merge!('HTTP_IF_MATCH' => @etags.try(:last))
          result = @request.put('/items/abc', options)
          @etags << JSON.parse(result.body)['etag']
        end
        @response = @request.get(
          '/items/abc/versions/_resolved', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
        @parsed_response = JSON.parse(@response.body)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should be successful even if the current resource has been deleted" do
        @request.delete(
          '/items/abc', {'HTTP_IF_MATCH' => @etags.last}.merge(VALID_TEST_AUTH))
        response = @request.get('/items/abc/versions/_resolved', VALID_TEST_AUTH)
        @response.status.should == 200
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].size.should == 4
      end

      it "should return all versions of a document" do
        documents = @parsed_response['documents']
        documents.should_not be_nil
        documents.size.should == 4
      end

      it "should return a 404 if the resource does not exist" do
        response = @request.get('/items/nothing/versions/_resolved', VALID_TEST_AUTH)
        response.status.should == 404
      end

      it "should return a 404 for non-owner-originated requests" do
        response = @request.get('/items/abc/versions/_resolved', CLOUDKIT_AUTH_KEY => 'someoneelse')
        response.status.should == 404
      end

      it "should sort descending on last_modified date" do
        @parsed_response['documents'].map{|d| d['uri']}.should == ['/items/abc'].concat(@etags[0..-2].reverse.map{|e| "/items/abc/versions/#{e}"})
      end

      it "should return the total number of documents" do
        @parsed_response['total'].should_not be_nil
        @parsed_response['total'].should == 4
      end

      it "should return the offset" do
        @parsed_response['offset'].should_not be_nil
        @parsed_response['offset'].should == 0
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified date" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should accept a limit parameter" do
        response = @request.get(
          '/items/abc/versions/_resolved?limit=2', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == ['/items/abc', "/items/abc/versions/#{@etags[-2]}"]
        parsed_response['total'].should == 4
      end

      it "should accept an offset parameter" do
        response = @request.get(
          '/items/abc/versions/_resolved?offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == @etags.reverse[1..-1].map{|e| "/items/abc/versions/#{e}"}
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 4
      end

      it "should accept combined limit and offset parameters" do
        response = @request.get(
          '/items/abc/versions/_resolved?limit=1&offset=1', VALID_TEST_AUTH)
        parsed_response = JSON.parse(response.body)
        parsed_response['documents'].map{|d| d['uri']}.should == ["/items/abc/versions/#{@etags[-2]}"]
        parsed_response['offset'].should == 1
        parsed_response['total'].should == 4
      end

      it "should return an index link header" do
        @response['Link'].should_not be_nil
        @response['Link'].match("<http://example.org/items/abc/versions>; rel=\"index\"").should_not be_nil
      end

    end

    describe "on GET /:collection/:id/versions/:etag" do

      before(:each) do
        @etags = []
        2.times do |i|
          json = JSON.generate(:this => i)
          options = {:input => json}.merge(VALID_TEST_AUTH)
          options.filter_merge!('HTTP_IF_MATCH' => @etags.try(:last))
          result = @request.put('/items/abc', options)
          @etags << JSON.parse(result.body)['etag']
        end
        @response = @request.get(
          "/items/abc/versions/#{@etags.first}", VALID_TEST_AUTH)
        @parsed_response = JSON.parse(@response.body)
      end

      it "should be successful" do
        @response.status.should == 200
      end

      it "should return a document for valid owner-originated requests" do
        @parsed_response['this'].should == 0
      end

      it "should return a 404 if a document is not found" do
        response = @request.get(
          "/items/nothing/versions/#{@etags.first}", VALID_TEST_AUTH)
        response.status.should == 404
      end

      it "should return a Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should return an ETag header" do
        @response['ETag'].should_not be_nil
      end

      it "should return a Last-Modified header" do
        @response['Last-Modified'].should_not be_nil
      end

      it "should not return documents for unauthorized users" do
        response = @request.get(
          "/items/abc/versions/#{@etags.first}", CLOUDKIT_AUTH_KEY => 'someoneelse')
        response.status.should == 404
      end

    end

    describe "on POST /:collection" do

      before(:each) do
        json = JSON.generate(:this => 'that')
        @response = @request.post(
          '/items', {:input => json}.merge(VALID_TEST_AUTH))
        @body = JSON.parse(@response.body)
      end

      it "should store the document" do
        result = @request.get(@body['uri'], VALID_TEST_AUTH)
        result.status.should == 200
      end

      it "should return a 201 when successful" do
        @response.status.should == 201
      end

      it "should return the metadata" do
        @body.keys.size.should == 4
        @body.keys.sort.should == ['etag', 'last_modified', 'ok', 'uri']
      end

      it "should set the Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should not set an ETag header" do
        @response['ETag'].should be_nil
      end

      it "should not set a Last-Modified header" do
        @response['Last-Modified'].should be_nil
      end

      it "should return a 422 if parsing fails" do
        response = @request.post('/items', {:input => 'fail'}.merge(VALID_TEST_AUTH))
        response.status.should == 422
      end

    end

    describe "on PUT /:collection/:id" do 

      before(:each) do
        json = JSON.generate(:this => 'that')
        @original = @request.put(
          '/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
        etag = JSON.parse(@original.body)['etag']
        json = JSON.generate(:this => 'other')
        @response = @request.put(
          '/items/abc',
          :input            => json,
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        @json = JSON.parse(@response.body)
      end

      it "should create a document if it does not already exist" do
        json = JSON.generate(:this => 'thing')
        response = @request.put(
          '/items/xyz', {:input => json}.merge(VALID_TEST_AUTH))
        response.status.should == 201
        result = @request.get('/items/xyz', VALID_TEST_AUTH)
        result.status.should == 200
        JSON.parse(result.body)['this'].should == 'thing'
      end

      it "should not create new resources using deleted resource URIs" do
        # This situation occurs when a stale client attempts to update
        # a resource that has been removed. This test verifies that CloudKit
        # does not attempt to create a new item with a URI equal to the
        # removed item.
        etag = JSON.parse(@response.body)['etag'];
        @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        json = JSON.generate(:foo => 'bar')
        response = @request.put(
          '/items/abc',
          :input            => json,
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 410
      end

      it "should update the document if it already exists" do
        @response.status.should == 200
        result = @request.get('/items/abc', VALID_TEST_AUTH)
        JSON.parse(result.body)['this'].should == 'other'
      end

      it "should return the metadata" do
        @json.keys.size.should == 4
        @json.keys.sort.should == ['etag', 'last_modified', 'ok', 'uri']
      end

      it "should set the Content-Type header" do
        @response['Content-Type'].should == 'application/json'
      end

      it "should not set an ETag header" do
        @response['ETag'].should be_nil
      end

      it "should not set a Last-Modified header" do
        @response['Last-Modified'].should be_nil
      end

      it "should not allow a remote_user change" do
        json = JSON.generate(:this => 'other')
        response = @request.put(
          '/items/abc',
          :input            => json,
          'HTTP_IF_MATCH'   => @json['etag'],
          CLOUDKIT_AUTH_KEY => 'someone_else')
        response.status.should == 404
      end

      it "should detect and return conflicts" do
        client_a_input = JSON.generate(:this => 'updated')
        client_b_input = JSON.generate(:other => 'thing')
        response = @request.put(
          '/items/abc',
          :input            => client_a_input,
          'HTTP_IF_MATCH'   => @json['etag'],
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 200
        response = @request.put(
          '/items/abc',
          :input            => client_b_input,
          'HTTP_IF_MATCH'   => @json['etag'],
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 412
      end

      it "should require an ETag for updates" do
        json = JSON.generate(:this => 'updated')
        response = @request.put(
          '/items/abc',
          {:input   => json}.merge(VALID_TEST_AUTH))
        response.status.should == 400
      end

      it "should return a 422 if parsing fails" do
        response = @request.put(
          '/items/zzz', {:input => 'fail'}.merge(VALID_TEST_AUTH))
        response.status.should == 422
      end

      it "should version document updates" do
        json = JSON.generate(:this => 'updated')
        response = @request.put(
          '/items/abc',
          :input             => json,
          'HTTP_IF_MATCH'    => @json['etag'],
          CLOUDKIT_AUTH_KEY  => TEST_REMOTE_USER)
        response.status.should == 200
        etag = JSON.parse(response.body)['etag']
        json = JSON.generate(:this => 'updated again')
        new_response = @request.put(
          '/items/abc',
          :input            => json,
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        new_response.status.should == 200
        new_etag = JSON.parse(new_response.body)['etag']
        new_etag.should_not == etag
      end

      describe "using POST method tunneling" do

        it "should behave like a PUT" do
          json = JSON.generate(:this => 'thing')
          response = @request.post(
            '/items/xyz?_method=PUT',
            {:input => json}.merge(VALID_TEST_AUTH))
          response.status.should == 201
          result = @request.get('/items/xyz', VALID_TEST_AUTH)
          result.status.should == 200
          JSON.parse(result.body)['this'].should == 'thing'
        end

      end

    end

    describe "on DELETE /:collection/:id" do

      before(:each) do
        json = JSON.generate(:this => 'that')
        @result = @request.put(
          '/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
        @etag = JSON.parse(@result.body)['etag']
      end

      it "should delete the document" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 200
        result = @request.get('/items/abc', VALID_TEST_AUTH)
        result.status.should == 410
      end

      it "should return the metadata" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        json = JSON.parse(response.body)
        json.keys.size.should == 4
        json.keys.sort.should == ['etag', 'last_modified', 'ok', 'uri']
      end

      it "should set the Content-Type header" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response['Content-Type'].should == 'application/json'
      end

      it "should not set an ETag header" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response['ETag'].should be_nil
      end

      it "should not set a Last-Modified header" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response['Last-Modified'].should be_nil
      end

      it "should return a 404 for items that have never existed" do
        response = @request.delete(
          '/items/zzz',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 404
      end

      it "should require an ETag" do
        response = @request.delete(
          '/items/abc',
          VALID_TEST_AUTH)
        response.status.should == 400
      end

      it "should verify the user in the doc" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => 'someoneelse')
        response.status.should == 404
      end

      it "should detect and return conflicts" do
        json = JSON.generate(:this => 'that')
        result = @request.put(
          '/items/123', {:input => json}.merge(VALID_TEST_AUTH))
        etag = JSON.parse(result.body)['etag']
        client_a_input = JSON.generate(:this => 'updated')
        client_b_input = JSON.generate(:other => 'thing')
        response = @request.put(
          '/items/123',
          :input            => client_a_input,
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 200
        response = @request.delete(
          '/items/123',
          :input            => client_b_input,
          'HTTP_IF_MATCH'   => etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 412
      end

      it "should retain version history" do
        response = @request.delete(
          '/items/abc',
          'HTTP_IF_MATCH'   => @etag,
          CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
        response.status.should == 200
        response = @request.get(
          '/items/abc/versions',
          VALID_TEST_AUTH)
        json = JSON.parse(response.body)
        json['total'].should == 1
      end

      describe "using POST method tunneling" do

        it "should behave like a DELETE" do
          response = @request.post(
            '/items/abc?_method=DELETE',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          response.status.should == 200
          result = @request.get('/items/abc', VALID_TEST_AUTH)
          result.status.should == 410
        end

      end

    end

    describe "on OPTIONS /:collection" do

      before(:each) do
        @response = @request.request('OPTIONS', '/items', VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['GET', 'HEAD', 'OPTIONS', 'POST']
      end

      describe "using POST method tunneling" do

        it "should behave like an OPTIONS request" do
          response = @request.post('/items?_method=OPTIONS', VALID_TEST_AUTH)
          response['Allow'].should_not be_nil
          methods = response['Allow'].split(', ')
          methods.sort.should == ['GET', 'HEAD', 'OPTIONS', 'POST']
        end
      end

    end

    describe "on OPTIONS /:collection/_resolved" do

      before(:each) do
        @response = @request.request('OPTIONS', '/items/_resolved', VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['GET', 'HEAD', 'OPTIONS']
      end

    end

    describe "on OPTIONS /:collection/:id" do

      before(:each) do
        @response = @request.request('OPTIONS', '/items/xyz', VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PUT']
      end

    end

    describe "on OPTIONS /:collection/:id/versions" do

      before(:each) do
        @response = @request.request('OPTIONS', '/items/xyz/versions', VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['GET', 'HEAD', 'OPTIONS']
      end

    end

    describe "on OPTIONS /:collection/:id/versions/_resolved" do

      before(:each) do
        @response = @request.request('OPTIONS', '/items/xyz/versions/_resolved', VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['GET', 'HEAD', 'OPTIONS']
      end

    end

    describe "on OPTIONS /:collection/:id/versions/:etag" do

      before(:each) do
        @response = @request.request('OPTIONS', "/items/xyz/versions/abc", VALID_TEST_AUTH)
      end

      it "should return a 200 status" do
        @response.status.should == 200
      end

      it "should return a list of available methods" do
        @response['Allow'].should_not be_nil
        methods = @response['Allow'].split(', ')
        methods.sort.should == ['GET', 'HEAD', 'OPTIONS']
      end

    end

    describe "on HEAD" do

      it "should return an empty body" do
        json = JSON.generate(:this => 'that')
        @request.put('/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
        response = @request.request('HEAD', '/items/abc', VALID_TEST_AUTH)
        response.body.should == ''
        response = @request.request('HEAD', '/items', VALID_TEST_AUTH)
        response.body.should == ''
      end

    end
  end
end
