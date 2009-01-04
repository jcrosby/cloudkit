require 'helper'
class RequestTest < Test::Unit::TestCase

  context "A Request" do

    should "match requests with routes" do
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com')).match?(
          'GET', '/')
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/')).match?(
          'GET', '/')
      assert !CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/')).match?(
          'POST', '/')
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello')).match?(
          'GET', '/hello')
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello')).match?(
          'GET', '/hello')
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello', :method => 'POST')).match?(
          'POST', '/hello')
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q=a', :method => 'POST')).match?(
          'POST', '/hello', [{'q' => 'a'}])
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q=a', :method => 'POST')).match?(
          'POST', '/hello', ['q'])
      assert !CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q=a', :method => 'POST')).match?(
          'POST', '/hello', [{'q' => 'b'}])
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q', :method => 'POST')).match?(
          'POST', '/hello', [{'q' => nil}])
      assert !CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q=a', :method => 'POST')).match?(
          'POST', '/hello', [{'q' => nil}])
      assert !CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q=a', :method => 'POST')).match?(
          'POST', '/hello', [{'q' => ''}])
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q&x=y', :method => 'PUT')).match?(
          'PUT', '/hello', ['q', {'x' => 'y'}])
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q&x=y&z', :method => 'PUT')).match?(
          'PUT', '/hello', ['q', {'x' => 'y'}])
      assert !CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello?q&x=y', :method => 'PUT')).match?(
          'PUT', '/hello', [{'q' => 'a'},{'x' => 'y'}])
    end

    should "treat a trailing :id as a wildcard for path matching" do
      assert CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://example.com/hello/123')).match?('GET', '/hello/:id')
    end

    should "inject stack-internal via-style env vars" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/test'))
      assert_equal [], request.via
      request.inject_via('a.b')
      assert request.via.include?('a.b')
      request.inject_via('c.d')
      assert request.via.include?('a.b')
      assert request.via.include?('c.d')
    end

    should "announce the use of auth middleware" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
      assert request.via.include?(CLOUDKIT_OAUTH_FILTER_KEY)
    end

    should "know if auth provided by upstream middleware" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
      assert request.using_auth?
    end

    should "know the current user" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      assert_nil request.current_user
      request = CloudKit::Request.new(
        Rack::MockRequest.env_for('/', CLOUDKIT_AUTH_KEY => 'cecil'))
      assert request.current_user
      assert_equal 'cecil', request.current_user
    end

    should "set the current user" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      request.current_user = 'cecil'
      assert request.current_user
      assert_equal 'cecil', request.current_user
    end

    should "know the login url" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      assert_equal '/login', request.login_url
      request = CloudKit::Request.new(
        Rack::MockRequest.env_for(
          '/', CLOUDKIT_LOGIN_URL => '/sessions'))
      assert_equal '/sessions', request.login_url
    end

    should "set the login url" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      request.login_url = '/welcome'
      assert_equal '/welcome', request.login_url
    end

    should "know the logout url" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      assert_equal '/logout', request.logout_url
      request = CloudKit::Request.new(
        Rack::MockRequest.env_for(
          '/', CLOUDKIT_LOGOUT_URL => '/sessions'))
      assert_equal '/sessions', request.logout_url
    end

    should "set the logout url" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      request.logout_url = '/goodbye'
      assert_equal '/goodbye', request.logout_url
    end

    should "get the session" do
      request = CloudKit::Request.new(
        Rack::MockRequest.env_for('/', 'rack.session' => 'this'))
      assert request.session
      assert_equal 'this', request.session
    end

    should "know the flash" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        '/', 'rack.session' => {}))
      assert request.flash.is_a?(CloudKit::FlashSession)
    end

    should "parse if-match headers" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        '/items/123/versions'))
      assert_nil request.if_match
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        '/items/123/versions',
        'HTTP_IF_MATCH' => '"a"'))
      assert_equal 'a', request.if_match
    end

    should "treat a list of etags in an if-match header as a single etag" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        '/items/123/versions',
        'HTTP_IF_MATCH' => '"a", "b"'))
      # See CloudKit::Request#if_match for more info on this expectation
      assert_equal 'a", "b', request.if_match 
    end

    should "ignore if-match when set to *" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        '/items/123/versions',
        'HTTP_IF_MATCH' => '*'))
      assert_nil request.if_match
    end

    should "understand header auth" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for(
        'http://photos.example.net/photos?file=vacation.jpg&size=original',
        'Authorization' =>
        'OAuth realm="",' + 
        'oauth_version="1.0",' +
        'oauth_consumer_key="dpf43f3p2l4k3l03",' +
        'oauth_token="nnch734d00sl2jdk",' +
        'oauth_timestamp="1191242096",' +
        'oauth_nonce="kllo9940pd9333jh",' +
        'oauth_signature="tR3%2BTy81lMeYAr%2FFid0kMTYa%2FWM%3D",' +
        'oauth_signature_method="HMAC-SHA1"'))
      assert_equal 'dpf43f3p2l4k3l03', request['oauth_consumer_key']
      assert_equal 'nnch734d00sl2jdk', request['oauth_token']
      assert_equal '1191242096', request['oauth_timestamp']
      assert_equal 'kllo9940pd9333jh', request['oauth_nonce']
      assert_equal 'tR3+Ty81lMeYAr/Fid0kMTYa/WM=', request['oauth_signature']
      assert_equal 'HMAC-SHA1', request['oauth_signature_method']
    end

    should "know the last path element" do
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/'))
      assert_nil request.last_path_element
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/abc'))
      assert_equal 'abc', request.last_path_element
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/abc/'))
      assert_equal 'abc', request.last_path_element
      request = CloudKit::Request.new(Rack::MockRequest.env_for('/abc/def'))
      assert_equal 'def', request.last_path_element
    end

  end
end
