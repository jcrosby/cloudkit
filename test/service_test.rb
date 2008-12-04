require 'helper'
class ServiceTest < Test::Unit::TestCase
  context "A CloudKit::Service" do
    setup do
      @request = Rack::MockRequest.new(plain_service)
    end
    teardown do
      FileUtils.rm_f('service.db')
    end
    should "return a 405 for known unsupported methods" do
      response = @request.request('TRACE', '/items')
      assert_equal 405, response.status
    end
    should "set the allow header for known unsupported methods" do
      response = @request.request('TRACE', '/items')
      assert response['Allow']
      methods = response['Allow'].split(', ')
      assert_same_elements ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], methods
    end
    should "return a 501 for unknown methods" do
      response = @request.request('REJUXTAPOSE', '/items')
      assert_equal 501, response.status
    end
    context "using auth" do
      setup do
        @store = service_store
        @request = Rack::MockRequest.new(authed_service)
      end
      should "allow requests to / to pass through" do
        response = @request.get('/')
        assert_equal 'martino', response.body
      end
      should "allow any non-specified resource request to pass through" do
        response = @request.get('/hammers')
        assert_equal 'martino', response.body
      end
      should "raise an error if a store is not supplied" do
        assert_raise ArgumentError do
          app = CloudKit::Service.new(
            lambda {|env| [200, {}, []]})
        end
      end
      should "return a 500 if misconfigured" do
        # simulate auth requirement without the auth_key being set by the
        # auth filter
        response = @request.get('/items')
        assert_equal 500, response.status
      end
      context "on HEAD" do
        should "return an empty body" do
          json = JSON.generate(:id => 'abc', :this => 'that')
          @store.put(
            :items, :id => 'abc', :data => json, :remote_user => remote_user)
          response = @request.request('HEAD', '/items/abc', auth_key => remote_user)
          assert_equal '', response.body
          response = @request.request('HEAD', '/items', auth_key => remote_user)
          assert_equal '', response.body
        end
      end
      context "on OPTIONS /:collection" do
        setup do
          @response = @request.request(
            'OPTIONS', '/items', auth_key => remote_user)
        end
        should "return a 200 status" do
          assert_equal 200, @response.status
        end
        should "return a list of available methods" do
          assert @response['Allow']
          methods = @response['Allow'].split(', ')
          assert_same_elements(
            ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], methods)
        end
      end
      context "on OPTIONS /:collection/:id" do
        setup do
          @response = @request.request(
            'OPTIONS', '/items/xyz', auth_key => remote_user)
        end
        should "return a 200 status" do
          assert_equal 200, @response.status
        end
        should "return a list of available methods" do
          assert @response['Allow']
          methods = @response['Allow'].split(', ')
          assert_same_elements(
            ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], methods)
        end
      end
      context "on GET /:collection" do
        should "return all owner-originated resources" do
          2.times do |i|
            json = JSON.generate(:id => i.to_s, :this => i.to_s)
            @store.put(
              :items, :id => i.to_s, :data => json, :remote_user => remote_user)
          end
          json = JSON.generate(:id => '3', :this => '3')
          @store.put(
            :items, :id => '3', :data => json, :remote_user => 'someoneelse')
          response = @request.get('/items', auth_key => remote_user)
          assert_equal 200, response.status
          documents = JSON.parse(response.body)['documents']
          assert documents
          assert_equal 2, documents.size
        end
      end
      context "on GET /:collection/meta" do
        should "return metadata for owner-originated resources" do
          2.times do |i|
            json = JSON.generate(:id => i.to_s, :this => i.to_s)
            @store.put(
              :items, :id => i.to_s, :data => json, :remote_user => remote_user)
          end
          json = JSON.generate(:id => '3', :this => '3')
          @store.put(
            :items, :id => '3', :data => json, :remote_user => 'someoneelse')
          response = @request.get('/items/meta', auth_key => remote_user)
          assert_equal 200, response.status
          documents = JSON.parse(response.body)['documents']
          assert documents
          assert_equal 2, documents.size
          documents.each do |doc|
            assert_same_elements ['last_modified', 'etag', 'id'], doc.keys
          end
        end
      end
      context "on GET /:collection/:id" do
        setup do
          json = JSON.generate(:id => 'abc', :this => 'that')
          @store.put(
            :items, :id => 'abc', :data => json, :remote_user => remote_user)
          @response = @request.get(
            '/items/abc', 'HTTP_HOST' => 'example.org', auth_key => remote_user)
        end
        should "return documents for valid owner-originated requests" do
          assert_equal 200, @response.status
          data = JSON.parse(@response.body)
          assert_equal 'that', data['this']
        end
        should "return an etag header" do
          assert @response['Etag']
        end
        should "return a last-modified header" do
          assert @response['Last-Modified']
        end
        should "not return documents for unauthorized users" do
          response = @request.get('/items/abc', auth_key => 'bogus')
          assert_equal 404, response.status
        end
        should "return a history link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/abc/history>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/history\"")
        end
        should "return an etags link header" do
          assert @response['Link']
          assert @response['Link'].match("<http://example.org/items/abc/etags>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/etags\"")
        end
      end
      context "on GET /:collection/:id/history" do
        setup do
          @etags = []
          4.times do |i|
            content = {:id => 'abc', :this => i}
            content.filter_merge!(:etag => @etags.try(:last))
            json = JSON.generate(content)
            options = {:id => 'abc', :data => json, :remote_user => remote_user}
            options.filter_merge!(:if_match => @etags.try(:last))
            result = @store.put(:items, options)
            @etags << result['Etag']
          end
        end
        should "return an array of all previous versions of a resource" do
          response = @request.get('/items/abc/history', auth_key => remote_user)
          assert_equal 200, response.status
          data = JSON.parse(response.body)
          documents = data['documents']
          assert documents
          assert_equal 3, documents.size
        end
        should "return a 404 if the resource does not exist" do
          response = @request.get('/items/nothing/history', auth_key => remote_user)
          assert_equal 404, response.status
        end
        should "return a 404 for non-owner-originated requests" do
          response = @request.get('/items/abc/history', auth_key => 'someoneelse')
          assert_equal 404, response.status
        end
        context "using If-Match" do
          should "return all documents matching the list of etags" do
            tags = build_etag_header(@etags)
            response = @request.get(
              '/items/abc/history',
              'HTTP_IF_MATCH' => tags,
              auth_key        => remote_user)
            assert_equal 200, response.status
            data = JSON.parse(response.body)
            documents = data['documents']
            assert documents
            assert_equal 3, documents.size
            @etags.shift
            tags = build_etag_header(@etags)
            response = @request.get(
              '/items/abc/history',
              'HTTP_IF_MATCH' => tags,
              auth_key        => remote_user)
            assert_equal 200, response.status
            data = JSON.parse(response.body)
            documents = data['documents']
            assert documents
            assert_equal 2, documents.size
          end
        end
        context "using If-None-Match" do
          should "return only the documents not matching the list of etags" do
            tags = build_etag_header(@etags)
            response = @request.get(
              '/items/abc/history',
              'HTTP_IF_NONE_MATCH' => tags,
              auth_key             => remote_user)
            assert_equal 200, response.status
            data = JSON.parse(response.body)
            documents = data['documents']
            assert_equal [], documents
            @etags.shift
            tags = build_etag_header(@etags)
            response = @request.get(
              '/items/abc/history',
              'HTTP_IF_NONE_MATCH' => tags,
              auth_key             => remote_user)
            assert_equal 200, response.status
            data = JSON.parse(response.body)
            documents = data['documents']
            assert documents
            assert_equal 1, documents.size
          end
        end
      end
      context "on GET /:collection/:id with a previously valid etag" do
        should "return a specific resource revision" do
          json = JSON.generate(:id => 'abc', :this => 'that')
          result = @store.put(
            :items, :id => 'abc', :data => json, :remote_user => remote_user)
          etag = result['Etag']
          json = JSON.generate(:id => 'abc', :this => 'other', :etag => etag)
          @store.put(
            :items,
            :id          => 'abc',
            :data        => json,
            :if_match    => etag,
            :remote_user => remote_user)
          response = @request.get(
            '/items/abc', 'HTTP_IF_MATCH' => etag, auth_key => remote_user)
          assert_equal 200, response.status
          assert_equal etag, response['Etag']
          data = JSON.parse(response.body)
          assert_equal 'that', data['this']
        end
      end
      context "on GET /:collection/:id/etags" do
        setup do
          @etags = []
          4.times do |i|
            content = {:id => 'abc', :this => i}
            content.filter_merge!(:etag => @etags.try(:last))
            json = JSON.generate(content)
            options = {:id => 'abc', :data => json, :remote_user => remote_user}
            options.filter_merge!(:if_match => @etags.try(:last))
            result = @store.put(:items, options)
            @etags << result['Etag']
          end
        end
        should "return all etags associated with a resource" do
          response = @request.get('/items/abc/etags', auth_key => remote_user)
          assert_equal 200, response.status
          etags = JSON.parse(response.body)['documents']
          assert_same_elements @etags, etags.map{|t| t['etag']}
        end
        should "not return etags for non-owner-originated resources" do
          response = @request.get('/items/abc/etags', auth_key => 'someoneelse')
          assert_equal 404, response.status
        end
      end
      context "on POST /:collection" do
        setup do
          json = JSON.generate(:this => 'that')
          @response = @request.post(
            '/items', :input => json, auth_key => remote_user)
          @body = JSON.parse(@response.body)
        end
        should "store the document" do
          result = @store.get(:items, :id => @body['id'])
          assert_equal 200, result.status
        end
        should "return a 201 when successful" do
          assert_equal 201, @response.status
        end
        should "return the document id" do
          assert @body['id']
        end
        should "set an etag header" do
          assert @response['Etag']
          assert_not_equal '', @response['Etag']
        end
        should "set the last-modified header" do
          assert @response['Last-Modified']
          assert_not_equal '', @response['Last-Modified']
        end
      end
      context "on PUT /:collection/:id" do 
        setup do
          json = JSON.generate(:id => 'abc', :this => 'that')
          @original = @store.put(
            :items, :id => 'abc', :data => json, :remote_user => remote_user)
          json = JSON.generate(
            :id => 'abc', :this => 'other', :etag => @original['Etag'])
          @response = @request.put(
            '/items/abc',
            :input          => json,
            'HTTP_IF_MATCH' => @original['Etag'],
            auth_key        => remote_user)
        end
        should "create a document if it does not already exist" do
          json = JSON.generate(:id => 'xyz', :this => 'thing')
          response = @request.put(
            '/items/xyz', :input => json, auth_key => remote_user)
          assert_equal 201, response.status
          result = @store.get(:items, :id => 'xyz')
          assert_equal 200, result.status
          assert_equal 'thing', result.parsed_content['this']
        end
        should "update the document if it already exists" do
          assert_equal 200, @response.status
          result = @store.get(:items, :id => 'abc').parsed_content
          assert_equal 'other', result['this']
        end
        should "set an etag header" do
          assert @response['Etag']
          assert_not_equal @response['Etag'], @original['Etag']
        end
        should "set the last-modified header" do
          assert @response['Last-Modified']
        end
        should "return the document id" do
          data = JSON.parse(@response.body)
          assert_equal 'abc', data['id']
        end
        should "not allow a remote_user change" do
          json = JSON.generate(
            :id   => 'abc',
            :this => 'other',
            :etag => @response['Etag'])
          response = @request.put(
            '/items/abc',
            :input          => json,
            'HTTP_IF_MATCH' => @response['Etag'],
            auth_key        => 'someone_else')
          assert_equal 404, response.status
        end
        should "detect and return conflicts" do
          client_a_input = JSON.generate(
            :id => 'abc', :etag => @response['Etag'], :this => 'updated')
          client_b_input = JSON.generate(
            :id => 'abc', :etag => @response['Etag'], :other => 'thing')
          response = @request.put(
            '/items/abc',
            :input          => client_a_input,
            'HTTP_IF_MATCH' => @response['Etag'],
            auth_key        => remote_user)
          assert_equal 200, response.status
          response = @request.put(
            '/items/abc',
            :input          => client_b_input,
            'HTTP_IF_MATCH' => @response['Etag'],
            auth_key        => remote_user)
          assert_equal 412, response.status
        end
      end
      context "on DELETE /:collection/:id" do
        setup do
          json = JSON.generate(:id => 'abc', :this => 'that')
          @result = @store.put(
            :items, :id => 'abc', :data => json, :remote_user => remote_user)
        end
        should "delete the document" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH' => @result['Etag'],
            auth_key        => remote_user)
          assert_equal 200, response.status
          result = @store.get(:items, :id => 'abc')
          assert_equal 410, result.status
        end
        should "set the last-modified header" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH' => @result['Etag'],
            auth_key        => remote_user)
          assert response['Last-Modified']
        end
        should "verify the user in the doc" do
          response = @request.delete(
            '/items/abc',
            'HTTP_IF_MATCH' => @result['Etag'],
            auth_key        => 'someoneelse')
          assert_equal 404, response.status
        end
        should "detect and return conflicts" do
          json = JSON.generate(:id => '123', :this => 'that')
          result = @store.put(
            :items, :id => '123', :data => json, :remote_user => remote_user)
          client_a_input = JSON.generate(
            :id => '123', :etag => result['Etag'], :this => 'updated')
          client_b_input = JSON.generate(
            :id => '123', :etag => result['Etag'], :other => 'thing')
          response = @request.put(
            '/items/123',
            :input          => client_a_input,
            'HTTP_IF_MATCH' => result['Etag'],
            auth_key        => remote_user)
          assert_equal 200, response.status
          response = @request.put(
            '/items/123',
            :input          => client_b_input,
            'HTTP_IF_MATCH' => result['Etag'],
            auth_key        => remote_user)
          assert_equal 412, response.status
        end
      end
    end
  end
end
