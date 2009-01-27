require 'helper'
class ServiceTest < Test::Unit::TestCase

  context "A CloudKit::Service" do

    should "return a 501 for unimplemented methods" do
      app = Rack::Builder.new {
        use Rack::Lint
        use CloudKit::Service, :collections => [:items, :things]
        run echo_text('martino')
      }

      response = Rack::MockRequest.new(app).request('TRACE', '/items')
      assert_equal 501, response.status

      # disable Rack::Lint so that an invalid HTTP method
      # can be tested
      app = Rack::Builder.new {
        use CloudKit::Service, :collections => [:items, :things]
        run echo_text('nothing')
      }
      response = Rack::MockRequest.new(app).request('REJUXTAPOSE', '/items')
      assert_equal 501, response.status
    end

    context "using auth" do

      setup do
        # mock an authenticated service in pieces
        mock_auth = Proc.new { |env|
          r = CloudKit::Request.new(env)
          r.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
        }
        inner_app = echo_text('martino')
        service = CloudKit::Service.new(
          inner_app, :collections => [:items, :things])
        config = Rack::Config.new(service, &mock_auth)
        authed_service = Rack::Lint.new(config)
        @request = Rack::MockRequest.new(authed_service)
      end

      should "allow requests for / to pass through" do
        response = @request.get('/')
        assert_equal 'martino', response.body
      end

      should "allow any non-specified resource request to pass through" do
        response = @request.get('/hammers')
        assert_equal 'martino', response.body
      end

      should "return a 500 if authentication is configured incorrectly" do
        # simulate auth requirement without CLOUDKIT_AUTH_KEY being set by the
        # auth filter(s)
        response = @request.get('/items')
        assert_equal 500, response.status
      end

      context "on GET /cloudkit-meta" do

        setup do
          @response = @request.get('/cloudkit-meta', VALID_TEST_AUTH)
        end

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "return a list of hosted collection URIs" do
          uris = JSON.parse(@response.body)['uris']
          assert_same_elements ['/things', '/items'], uris
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag" do
          assert @response['ETag']
        end

        should "not set a Last-Modified header" do
          assert_nil @response['Last-Modified']
        end
      end

      context "on GET /:collection" do

        setup do
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

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "return a list of URIs for all owner-originated resources" do
          assert_same_elements ['/items/0', '/items/1', '/items/2'],
            @parsed_response['uris']
        end

        should "sort descending on last_modified date" do
          assert_equal ['/items/2', '/items/1', '/items/0'],
            @parsed_response['uris']
        end

        should "return the total number of uris" do
          assert @parsed_response['total']
          assert_equal 3, @parsed_response['total']
        end

        should "return the offset" do
          assert @parsed_response['offset']
          assert_equal 0, @parsed_response['offset']
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag" do
          assert @response['ETag']
        end

        should "return a Last-Modified date" do
          assert @response['Last-Modified']
        end

        should "accept a limit parameter" do
          response = @request.get('/items?limit=2', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/2', '/items/1'], parsed_response['uris']
          assert_equal 3, parsed_response['total']
        end

        should "accept an offset parameter" do
          response = @request.get('/items?offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/1', '/items/0'], parsed_response['uris']
          assert_equal 1, parsed_response['offset']
          assert_equal 3, parsed_response['total']
        end

        should "accept combined limit and offset parameters" do
          response = @request.get('/items?limit=1&offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/1'], parsed_response['uris']
          assert_equal 1, parsed_response['offset']
          assert_equal 3, parsed_response['total']
        end

        should "return an empty list if no resources are found" do
          response = @request.get('/things', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal [], parsed_response['uris']
          assert_equal 0, parsed_response['total']
          assert_equal 0, parsed_response['offset']
        end

        should "return a resolved link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\"")
        end
      end

      context "on GET /:collection/_resolved" do

        setup do
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

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "return all owner-originated documents" do
          assert_same_elements ['/items/0', '/items/1', '/items/2'],
            @parsed_response['documents'].map{|d| d['uri']}
        end

        should "sort descending on last_modified date" do
          assert_equal ['/items/2', '/items/1', '/items/0'],
            @parsed_response['documents'].map{|d| d['uri']}
        end

        should "return the total number of documents" do
          assert @parsed_response['total']
          assert_equal 3, @parsed_response['total']
        end

        should "return the offset" do
          assert @parsed_response['offset']
          assert_equal 0, @parsed_response['offset']
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag" do
          assert @response['ETag']
        end

        should "return a Last-Modified date" do
          assert @response['Last-Modified']
        end

        should "accept a limit parameter" do
          response = @request.get('/items/_resolved?limit=2', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/2', '/items/1'],
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 3, parsed_response['total']
        end

        should "accept an offset parameter" do
          response = @request.get('/items/_resolved?offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/1', '/items/0'],
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 1, parsed_response['offset']
          assert_equal 3, parsed_response['total']
        end

        should "accept combined limit and offset parameters" do
          response = @request.get('/items/_resolved?limit=1&offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/1'],
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 1, parsed_response['offset']
          assert_equal 3, parsed_response['total']
        end

        should "return an empty list if no documents are found" do
          response = @request.get('/things/_resolved', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal [], parsed_response['documents']
          assert_equal 0, parsed_response['total']
          assert_equal 0, parsed_response['offset']
        end

        should "return an index link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items>; rel=\"index\"")
        end
      end

      context "on GET /:collection/:id" do

        setup do
          json = JSON.generate(:this => 'that')
          @request.put('/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
          @response = @request.get(
            '/items/abc', {'HTTP_HOST' => 'example.org'}.merge(VALID_TEST_AUTH))
        end

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "return a document for valid owner-originated requests" do
          data = JSON.parse(@response.body)
          assert_equal 'that', data['this']
        end

        should "return a 404 if a document does not exist" do
          response = @request.get('/items/nothing', VALID_TEST_AUTH)
          assert_equal 404, response.status
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag header" do
          assert @response['ETag']
        end

        should "return a Last-Modified header" do
          assert @response['Last-Modified']
        end

        should "not return documents for unauthorized users" do
          response = @request.get('/items/abc', CLOUDKIT_AUTH_KEY => 'bogus')
          assert_equal 404, response.status
        end

        should "return a versions link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/abc/versions>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/versions\"")
        end
      end

      context "on GET /:collection/:id/versions" do

        setup do
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

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "be successful even if the current resource has been deleted" do
          @request.delete('/items/abc', {'HTTP_IF_MATCH' => @etags.last}.merge(VALID_TEST_AUTH))
          response = @request.get('/items/abc/versions', VALID_TEST_AUTH)
          assert_equal 200, @response.status
          parsed_response = JSON.parse(response.body)
          assert_equal 4, parsed_response['uris'].size
        end

        should "return a list of URIs for all versions of a resource" do
          uris = @parsed_response['uris']
          assert uris
          assert_equal 4, uris.size
        end

        should "return a 404 if the resource does not exist" do
          response = @request.get('/items/nothing/versions', VALID_TEST_AUTH)
          assert_equal 404, response.status
        end

        should "return a 404 for non-owner-originated requests" do
          response = @request.get(
            '/items/abc/versions', CLOUDKIT_AUTH_KEY => 'someoneelse')
          assert_equal 404, response.status
        end

        should "sort descending on last_modified date" do
          assert_equal(
            ['/items/abc'].concat(@etags[0..-2].reverse.map{|e| "/items/abc/versions/#{e}"}),
            @parsed_response['uris'])
        end

        should "return the total number of uris" do
          assert @parsed_response['total']
          assert_equal 4, @parsed_response['total']
        end

        should "return the offset" do
          assert @parsed_response['offset']
          assert_equal 0, @parsed_response['offset']
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag" do
          assert @response['ETag']
        end

        should "return a Last-Modified date" do
          assert @response['Last-Modified']
        end

        should "accept a limit parameter" do
          response = @request.get('/items/abc/versions?limit=2', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/abc', "/items/abc/versions/#{@etags[-2]}"],
            parsed_response['uris']
          assert_equal 4, parsed_response['total']
        end

        should "accept an offset parameter" do
          response = @request.get('/items/abc/versions?offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal @etags.reverse[1..-1].map{|e| "/items/abc/versions/#{e}"},
            parsed_response['uris']
          assert_equal 1, parsed_response['offset']
          assert_equal 4, parsed_response['total']
        end

        should "accept combined limit and offset parameters" do
          response = @request.get('/items/abc/versions?limit=1&offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ["/items/abc/versions/#{@etags[-2]}"], parsed_response['uris']
          assert_equal 1, parsed_response['offset']
          assert_equal 4, parsed_response['total']
        end

        should "return a resolved link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/abc/versions/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\"")
        end
      end

      context "on GET /:collections/:id/versions/_resolved" do

        setup do
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

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "be successful even if the current resource has been deleted" do
          @request.delete(
            '/items/abc', {'HTTP_IF_MATCH' => @etags.last}.merge(VALID_TEST_AUTH))
          response = @request.get('/items/abc/versions/_resolved', VALID_TEST_AUTH)
          assert_equal 200, @response.status
          parsed_response = JSON.parse(response.body)
          assert_equal 4, parsed_response['documents'].size
        end

        should "return all versions of a document" do
          documents = @parsed_response['documents']
          assert documents
          assert_equal 4, documents.size
        end

        should "return a 404 if the resource does not exist" do
          response = @request.get('/items/nothing/versions/_resolved', VALID_TEST_AUTH)
          assert_equal 404, response.status
        end

        should "return a 404 for non-owner-originated requests" do
          response = @request.get('/items/abc/versions/_resolved', CLOUDKIT_AUTH_KEY => 'someoneelse')
          assert_equal 404, response.status
        end

        should "sort descending on last_modified date" do
          assert_equal(
            ['/items/abc'].concat(@etags[0..-2].reverse.map{|e| "/items/abc/versions/#{e}"}),
            @parsed_response['documents'].map{|d| d['uri']})
        end

        should "return the total number of documents" do
          assert @parsed_response['total']
          assert_equal 4, @parsed_response['total']
        end

        should "return the offset" do
          assert @parsed_response['offset']
          assert_equal 0, @parsed_response['offset']
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag" do
          assert @response['ETag']
        end

        should "return a Last-Modified date" do
          assert @response['Last-Modified']
        end

        should "accept a limit parameter" do
          response = @request.get(
            '/items/abc/versions/_resolved?limit=2', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ['/items/abc', "/items/abc/versions/#{@etags[-2]}"],
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 4, parsed_response['total']
        end

        should "accept an offset parameter" do
          response = @request.get(
            '/items/abc/versions/_resolved?offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal @etags.reverse[1..-1].map{|e| "/items/abc/versions/#{e}"},
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 1, parsed_response['offset']
          assert_equal 4, parsed_response['total']
        end

        should "accept combined limit and offset parameters" do
          response = @request.get(
            '/items/abc/versions/_resolved?limit=1&offset=1', VALID_TEST_AUTH)
          parsed_response = JSON.parse(response.body)
          assert_equal ["/items/abc/versions/#{@etags[-2]}"],
            parsed_response['documents'].map{|d| d['uri']}
          assert_equal 1, parsed_response['offset']
          assert_equal 4, parsed_response['total']
        end

        should "return an index link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/abc/versions>; rel=\"index\"")
        end
      end

      context "on GET /:collection/:id/versions/:etag" do

        setup do
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

        should "be successful" do
          assert_equal 200, @response.status
        end

        should "return a document for valid owner-originated requests" do
          assert_equal 0, @parsed_response['this']
        end

        should "return a 404 if a document is not found" do
          response = @request.get(
            "/items/nothing/versions/#{@etags.first}", VALID_TEST_AUTH)
          assert_equal 404, response.status
        end

        should "return a Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "return an ETag header" do
          assert @response['ETag']
        end

        should "return a Last-Modified header" do
          assert @response['Last-Modified']
        end

        should "not return documents for unauthorized users" do
          response = @request.get(
            "/items/abc/versions/#{@etags.first}", CLOUDKIT_AUTH_KEY => 'someoneelse')
          assert_equal 404, response.status
        end
      end

      context "on POST /:collection" do

        setup do
          json = JSON.generate(:this => 'that')
          @response = @request.post(
            '/items', {:input => json}.merge(VALID_TEST_AUTH))
          @body = JSON.parse(@response.body)
        end

        should "store the document" do
          result = @request.get(@body['uri'], VALID_TEST_AUTH)
          assert_equal 200, result.status
        end

        should "return a 201 when successful" do
          assert_equal 201, @response.status
        end

        should "return the metadata" do
          assert_equal 4, @body.keys.size
          assert_same_elements ['ok', 'uri', 'etag', 'last_modified'], @body.keys
        end

        should "set the Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "not set an ETag header" do
          assert_nil @response['ETag']
        end

        should "not set a Last-Modified header" do
          assert_nil @response['Last-Modified']
        end

        should "return a 422 if parsing fails" do
          response = @request.post('/items', {:input => 'fail'}.merge(VALID_TEST_AUTH))
          assert_equal 422, response.status
        end

        should "insert into its views" do
          view = CloudKit::ExtractionView.new(
            :fruits,
            :observe => :items,
            :extract => [:apple, :lemon])
          store = CloudKit::Store.new(
            :collections => [:items],
            :views       => [view])
          json = JSON.generate(:apple => 'green')
          store.put('/items/123', :json => json)
          json = JSON.generate(:apple => 'red')
          store.put('/items/456', :json => json)
          result = store.get('/fruits', :apple => 'green')
          uris = result.parsed_content['uris']
          assert_equal 1, uris.size
          assert uris.include?('/items/123')
        end
      end

      context "on PUT /:collection/:id" do 

        setup do
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

        should "create a document if it does not already exist" do
          json = JSON.generate(:this => 'thing')
          response = @request.put(
            '/items/xyz', {:input => json}.merge(VALID_TEST_AUTH))
          assert_equal 201, response.status
          result = @request.get('/items/xyz', VALID_TEST_AUTH)
          assert_equal 200, result.status
          assert_equal 'thing', JSON.parse(result.body)['this']
        end

        should "not create new resources using deleted resource URIs" do
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
          assert_equal 410, response.status
        end

        should "update the document if it already exists" do
          assert_equal 200, @response.status
          result = @request.get('/items/abc', VALID_TEST_AUTH)
          assert_equal 'other', JSON.parse(result.body)['this']
        end

        should "return the metadata" do
          assert_equal 4, @json.keys.size
          assert_same_elements ['ok', 'uri', 'etag', 'last_modified'], @json.keys
        end

        should "set the Content-Type header" do
          assert_equal 'application/json', @response['Content-Type']
        end

        should "not set an ETag header" do
          assert_nil @response['ETag']
        end

        should "not set a Last-Modified header" do
          assert_nil @response['Last-Modified']
        end

        should "not allow a remote_user change" do
          json = JSON.generate(:this => 'other')
          response = @request.put(
            '/items/abc',
            :input            => json,
            'HTTP_IF_MATCH'   => @json['etag'],
            CLOUDKIT_AUTH_KEY => 'someone_else')
          assert_equal 404, response.status
        end

        should "detect and return conflicts" do
          client_a_input = JSON.generate(:this => 'updated')
          client_b_input = JSON.generate(:other => 'thing')
          response = @request.put(
            '/items/abc',
            :input            => client_a_input,
            'HTTP_IF_MATCH'   => @json['etag'],
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 200, response.status
          response = @request.put(
            '/items/abc',
            :input            => client_b_input,
            'HTTP_IF_MATCH'   => @json['etag'],
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 412, response.status
        end

        should "require an ETag for updates" do
          json = JSON.generate(:this => 'updated')
          response = @request.put(
            '/items/abc',
            {:input   => json}.merge(VALID_TEST_AUTH))
          assert_equal 400, response.status
        end

        should "return a 422 if parsing fails" do
          response = @request.put(
            '/items/zzz', {:input => 'fail'}.merge(VALID_TEST_AUTH))
          assert_equal 422, response.status
        end

        should "version document updates" do
          json = JSON.generate(:this => 'updated')
          response = @request.put(
            '/items/abc',
            :input          => json,
            'HTTP_IF_MATCH' => @json['etag'],
            CLOUDKIT_AUTH_KEY        => TEST_REMOTE_USER)
          assert_equal 200, response.status
          etag = JSON.parse(response.body)['etag']
          json = JSON.generate(:this => 'updated again')
          new_response = @request.put(
            '/items/abc',
            :input            => json,
            'HTTP_IF_MATCH'   => etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 200, new_response.status
          new_etag = JSON.parse(new_response.body)['etag']
          assert_not_equal etag, new_etag
        end

        should "update its views" do
          view = CloudKit::ExtractionView.new(
            :fruits,
            :observe => :items,
            :extract => [:apple, :lemon])
          store = CloudKit::Store.new(
            :collections => [:items],
            :views       => [view])
          json = JSON.generate(:apple => 'green')
          result = store.put('/items/123', :json => json)
          json = JSON.generate(:apple => 'red')
          store.put(
            '/items/123', :etag => result.parsed_content['etag'], :json => json)
          result = store.get('/fruits', :apple => 'green')
          uris = result.parsed_content['uris']
          assert_equal 0, uris.size
          result = store.get('/fruits', :apple => 'red')
          uris = result.parsed_content['uris']
          assert_equal 1, uris.size
          assert uris.include?('/items/123')
        end
      end

      context "on DELETE /:collection/:id" do

        setup do
          json = JSON.generate(:this => 'that')
          @result = @request.put(
            '/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
          @etag = JSON.parse(@result.body)['etag']
        end

        should "delete the document" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 200, response.status
          result = @request.get('/items/abc', VALID_TEST_AUTH)
          assert_equal 410, result.status
        end

        should "return the metadata" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          json = JSON.parse(response.body)
          assert_equal 4, json.keys.size
          assert_same_elements ['ok', 'uri', 'etag', 'last_modified'], json.keys
        end

        should "set the Content-Type header" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 'application/json', response['Content-Type']
        end

        should "not set an ETag header" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_nil response['ETag']
        end

        should "not set a Last-Modified header" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_nil response['Last-Modified']
        end

        should "return a 404 for items that have never existed" do
          response = @request.delete(
            '/items/zzz',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 404, response.status
        end

        should "require an ETag" do
          response = @request.delete(
            '/items/abc',
            VALID_TEST_AUTH)
          assert_equal 400, response.status
        end

        should "verify the user in the doc" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => 'someoneelse')
          assert_equal 404, response.status
        end

        should "detect and return conflicts" do
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
          assert_equal 200, response.status
          response = @request.delete(
            '/items/123',
            :input            => client_b_input,
            'HTTP_IF_MATCH'   => etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 412, response.status
        end

        should "retain version history" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH'   => @etag,
            CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER)
          assert_equal 200, response.status
          response = @request.get(
            '/items/abc/versions',
            VALID_TEST_AUTH)
          json = JSON.parse(response.body)
          assert_equal 1, json['total']
        end

        should "remove records from its views" do
          view = CloudKit::ExtractionView.new(
            :fruits,
            :observe => :items,
            :extract => [:apple, :lemon])
          store = CloudKit::Store.new(
            :collections => [:items],
            :views       => [view])
          json = JSON.generate(:apple => 'green')
          result = store.put('/items/123', :json => json)
          store.delete('/items/123', :etag => result.parsed_content['etag'])
          result = store.get('/fruits', :apple => 'green')
          uris = result.parsed_content['uris']
          assert_equal [], uris
        end
      end

      context "on OPTIONS /:collection" do

        setup do
          @response = @request.request('OPTIONS', '/items', VALID_TEST_AUTH)
        end

        should "return a 200 status" do
          assert_equal 200, @response.status
        end

        should "return a list of available methods" do
          assert @response['Allow']
          methods = @response['Allow'].split(', ')
          assert_same_elements(['GET', 'POST', 'HEAD', 'OPTIONS'], methods)
        end
      end

      context "on OPTIONS /:collection/_resolved" do
      end

      context "on OPTIONS /:collection/:id" do

        setup do
          @response = @request.request('OPTIONS', '/items/xyz', VALID_TEST_AUTH)
        end

        should "return a 200 status" do
          assert_equal 200, @response.status
        end

        should "return a list of available methods" do
          assert @response['Allow']
          methods = @response['Allow'].split(', ')
          assert_same_elements(['GET', 'PUT', 'DELETE', 'HEAD', 'OPTIONS'], methods)
        end
      end

      context "on OPTIONS /:collection/:id/versions" do
      end

      context "on OPTIONS /:collection/:id/versions/_resolved" do
      end

      context "on OPTIONS /:collection/:id/versions/:etag" do
      end

      context "on HEAD" do

        should "return an empty body" do
          json = JSON.generate(:this => 'that')
          @request.put('/items/abc', {:input => json}.merge(VALID_TEST_AUTH))
          response = @request.request('HEAD', '/items/abc', VALID_TEST_AUTH)
          assert_equal '', response.body
          response = @request.request('HEAD', '/items', VALID_TEST_AUTH)
          assert_equal '', response.body
        end

      end
    end
  end
end
