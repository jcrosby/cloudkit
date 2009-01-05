require 'helper'
class OAuthFilterTest < Test::Unit::TestCase

  context "An OAuthFilter" do

    setup do
      @oauth_filtered_app = CloudKit::OAuthFilter.new(echo_env(CLOUDKIT_AUTH_KEY))
      token = JSON.generate(
        :secret          => 'pfkkdhi9sl3r4s00',
        :consumer_key    => 'dpf43f3p2l4k3l03',
        :consumer_secret => 'kd94hf93k423kf44',
        :user_id         => 'martino')
      Rack::MockRequest.new(@oauth_filtered_app).get('/') # prime the storage
      @store = @oauth_filtered_app.store
      result = @store.put('/cloudkit_oauth_tokens/nnch734d00sl2jdk', :json => token)
      @token_etag = result.parsed_content['etag']
    end

    teardown do
      @store.reset!
      @store.load_static_consumer
    end

    should "verify signatures" do
      response = do_get
      assert_equal 200, response.status
      assert_equal 'martino', response.body
    end

    should "notify downstream nodes of its presence" do
      app = CloudKit::OAuthFilter.new(echo_env(CLOUDKIT_VIA))
      response = Rack::MockRequest.new(app).get('/')
      assert_equal CLOUDKIT_OAUTH_FILTER_KEY, response.body
    end

    should "not allow a nonce/timestamp combination to appear twice" do
      do_get
      response = do_get
      assert_equal '', response.body
      get_request_token
      response = get_request_token
      assert_equal 401, response.status
    end

    should "add the remote user to the rack environment for verified requests" do
      response = do_get
      assert_equal 'martino', response.body
    end

    should "allow requests for / to pass through" do
      response = Rack::MockRequest.new(@oauth_filtered_app).get('/')
      assert_equal 200, response.status
    end

    should "reject unauthorized requests" do
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        'http://photos.example.net/photos?file=vacation.jpg&size=original' +
        '&oauth_version=1.0' +
        '&oauth_consumer_key=dpf43f3p2l4k3l03' +
        '&oauth_token=nnch734d00sl2jdk' +
        '&oauth_timestamp=1191242096' +
        '&oauth_nonce=kllo9940pd9333jh' +
        '&oauth_signature=fail'+
        '&oauth_signature_method=HMAC-SHA1', 'X-Remote-User' => 'intruder') # TODO rework
      assert_equal '', response.body
    end

    context "supporting OAuth Discovery" do

      should "set the auth challenge for unauthorized requests" do
        app = CloudKit::OAuthFilter.new(
          lambda {|env| [200, {}, [env[CLOUDKIT_AUTH_CHALLENGE]['WWW-Authenticate'] || '']]})
        response = Rack::MockRequest.new(app).get(
          '/items', 'HTTP_HOST' => 'example.org')
        assert_equal 'OAuth realm="http://example.org"', response.body
        app = CloudKit::OAuthFilter.new(
          lambda {|env| [200, {}, [env[CLOUDKIT_AUTH_CHALLENGE]['Link'] || '']]})
        response = Rack::MockRequest.new(app).get(
          '/items', 'HTTP_HOST' => 'example.org')
        assert_equal '<http://example.org/oauth/meta>; rel="http://oauth.net/discovery/1.0/rel/provider"',
          response.body
      end

      should "provide XRD metadata on GET /oauth/meta" do
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          '/oauth/meta', 'HTTP_HOST' => 'example.org')
        assert_equal 200, response.status
        doc = REXML::Document.new(response.body)
        assert REXML::XPath.first(doc, '//XRD/Type')
        assert_equal 'http://oauth.net/discovery/1.0',
          REXML::XPath.first(doc, '//XRD/Type').children[0].to_s
        assert REXML::XPath.first(doc, '//XRD/Service/Type')
        assert_equal 'http://oauth.net/discovery/1.0/rel/provider',
          REXML::XPath.first(doc, '//XRD/Service/Type').children[0].to_s
        assert REXML::XPath.first(doc, '//XRD/Service/URI')
        assert_equal 'http://example.org/oauth',
          REXML::XPath.first(doc, '//XRD/Service/URI').children[0].to_s
      end

      should "respond to OAuth Discovery Draft 2 / XRDS-Simple Discovery" do
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          '/anything',
          'HTTP_HOST'   => 'example.org',
          'HTTP_ACCEPT' => 'application/xrds+xml')
        assert 200, response.status
        assert_equal 'http://example.org/oauth', response['X-XRDS-Location']
      end

      should "provide a descriptor document on GET /oauth" do
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          '/oauth', 'HTTP_HOST' => 'example.org')
        assert_equal 200, response.status
        assert_equal 'application/xrds+xml', response['Content-Type']
      end

      should "populate the static consumer on startup" do
        response = @store.get('/cloudkit_oauth_consumers/cloudkitconsumer')
        assert_equal 200, response.status
      end

    end

    context "supporting authorization" do

      should "generate request tokens" do
        response = get_request_token
        assert_equal 201, response.status
        token, secret = response.body.split('&')
        token_parts = token.split('=')
        secret_parts = secret.split('=')
        assert_equal 'oauth_token', token_parts.first
        assert_equal 'oauth_token_secret', secret_parts.first
        assert token_parts.last
        assert !token_parts.last.empty?
        assert secret_parts.last
        assert !secret_parts.last.empty?
      end

      should "not generate request tokens for invalid consumers" do  
        # this does not mean consumers must register, only that they
        # should use the static value provided in the xrd document
        # or one that is specified in the consumer database
        pre_sign = Rack::Request.new(Rack::MockRequest.env_for(
          'http://photos.example.net/oauth/request_tokens',
          'Authorization' => 'OAuth realm="http://photos.example.net", ' +
          'oauth_version="1.0", ' +
          'oauth_consumer_key="mysteryconsumer", ' +
          'oauth_timestamp="1191242096", ' +
          'oauth_nonce="AAAAAAAAAAAAAAAAA", ' +
          'oauth_signature_method="HMAC-SHA1"',
          :method => "POST"))
        signature = OAuth::Signature.build(pre_sign) do |token, consumer_key|
          [nil, '']
        end
        response = Rack::MockRequest.new(@oauth_filtered_app).post(
          'http://photos.example.net/oauth/request_tokens?' +
          'oauth_version=1.0' +
          '&oauth_consumer_key=mysteryconsumer' +
          '&oauth_timestamp=1191242096' +
          '&oauth_nonce=AAAAAAAAAAAAAAAAA' +
          '&oauth_signature=' + CGI.escape(signature.signature) +
          '&oauth_signature_method=HMAC-SHA1')
        assert_equal 401, response.status
      end

      should "store request tokens for authorizaton" do
        response = get_request_token
        assert_equal 201, response.status
        token, secret = extract_token(response)
        request_token = @store.get("/cloudkit_oauth_request_tokens/#{token}").parsed_content
        assert request_token
        assert_equal secret, request_token['secret']
        assert !request_token['authorized_at']
      end

      should "redirect to login before allowing GET requests for request token authorization" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          "/oauth/authorization?oauth_token=#{token}")
        assert_equal 302, response.status
        assert_equal '/login', response['Location']
      end

      should "respond successfully to authorization GET requests for logged-in users with a valid request token" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          "/oauth/authorization?oauth_token=#{token}", VALID_TEST_AUTH)
        assert_equal 200, response.status
      end

      should "reject authorization GET requests with invalid tokens" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).get(
          "/oauth/authorization?oauth_token=fail", VALID_TEST_AUTH)
        assert_equal 401, response.status
      end

      should "authorize request tokens for verified requests" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).put(
          "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
        assert_equal 200, response.status
        request_token = @store.get("/cloudkit_oauth_request_tokens/#{token}").parsed_content
        assert request_token['authorized_at']
        assert request_token['user_id']
      end

      should "removed denied request tokens" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).put(
          "/oauth/authorized_request_tokens/#{token}?submit=Deny", VALID_TEST_AUTH)
        assert_equal 200, response.status
        request_token = @store.get("/cloudkit_oauth_request_tokens/#{token}").parsed_content
        assert 410, response.status
      end

      should "redirect to login for authorization PUT requests unless logged-in" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).put(
          "/oauth/authorized_request_tokens/#{token}?submit=Approve")
        assert_equal 302, response.status
        assert_equal '/login', response['Location']
      end

      should "not create access tokens for request tokens that have already been authorized" do
        response = get_request_token
        token, secret = extract_token(response)
        response = Rack::MockRequest.new(@oauth_filtered_app).put(
          "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
        assert_equal 200, response.status
        response = Rack::MockRequest.new(@oauth_filtered_app).put(
          "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
        assert_equal 401, response.status
      end

      should "provide access tokens in exchange for authorized request tokens" do
        response = get_access_token
        assert_equal 201, response.status
        token, secret = extract_token(response)
        assert !token.empty?
        assert !secret.empty?
      end

      should "remove request tokens after creating access tokens" do
        response = get_access_token
        assert_equal 201, response.status
        request_tokens = @store.get('/cloudkit_oauth_request_tokens').parsed_content
        assert_equal 0, request_tokens['uris'].size
      end

    end
  end

  def do_get
    Rack::MockRequest.new(@oauth_filtered_app).get(
      'http://photos.example.net/photos?file=vacation.jpg&size=original' +
      '&oauth_version=1.0' +
      '&oauth_consumer_key=dpf43f3p2l4k3l03' +
      '&oauth_token=nnch734d00sl2jdk' +
      '&oauth_timestamp=1191242096' +
      '&oauth_nonce=kllo9940pd9333jh' +
      '&oauth_signature=tR3%2BTy81lMeYAr%2FFid0kMTYa%2FWM%3D' +
      '&oauth_signature_method=HMAC-SHA1')
  end

  def get_request_token
    pre_sign = Rack::Request.new(Rack::MockRequest.env_for(
      'http://photos.example.net/oauth/request_tokens',
      'Authorization' => 'OAuth realm="http://photos.example.net", ' +
      'oauth_version="1.0", ' +
      'oauth_consumer_key="cloudkitconsumer", ' +
      'oauth_timestamp="1191242096", ' +
      'oauth_nonce="AAAAAAAAAAAAAAAAA", ' +
      'oauth_signature_method="HMAC-SHA1"',
      :method => "POST"))
    signature = OAuth::Signature.build(pre_sign) do |token, consumer_key|
      [nil, '']
    end
    Rack::MockRequest.new(@oauth_filtered_app).post(
      'http://photos.example.net/oauth/request_tokens?' +
      'oauth_version=1.0' +
      '&oauth_consumer_key=cloudkitconsumer' +
      '&oauth_timestamp=1191242096' +
      '&oauth_nonce=AAAAAAAAAAAAAAAAA' +
      '&oauth_signature=' + CGI.escape(signature.signature) +
      '&oauth_signature_method=HMAC-SHA1')
  end

  def get_access_token
    response = get_request_token
    token, secret = extract_token(response)
    response = Rack::MockRequest.new(@oauth_filtered_app).put(
      "/oauth/authorized_request_tokens/#{token}", VALID_TEST_AUTH)
    assert_equal 200, response.status
    pre_sign = Rack::Request.new(Rack::MockRequest.env_for(
      'http://photos.example.net/oauth/access_tokens',
      'Authorization' => 'OAuth realm="http://photos.example.net", ' +
      'oauth_version="1.0", ' +
      'oauth_consumer_key="cloudkitconsumer", ' +
      'oauth_token="' + token + '", ' +
      'oauth_timestamp="1191242097", ' +
      'oauth_nonce="AAAAAAAAAAAAAAAAA", ' +
      'oauth_signature_method="HMAC-SHA1"',
      :method => "POST"))
    signature = OAuth::Signature.build(pre_sign) do |token, consumer_key|
      [secret, '']
    end
    Rack::MockRequest.new(@oauth_filtered_app).post(
      'http://photos.example.net/oauth/access_tokens?' +
      'oauth_version=1.0' +
      '&oauth_consumer_key=cloudkitconsumer' +
      '&oauth_token=' + token +
      '&oauth_timestamp=1191242097' +
      '&oauth_nonce=AAAAAAAAAAAAAAAAA' +
      '&oauth_signature=' + CGI.escape(signature.signature) +
      '&oauth_signature_method=HMAC-SHA1')
  end

  def extract_token(response)
    token, secret = response.body.split('&')
    token_parts = token.split('=')
    secret_parts = secret.split('=')
    return token_parts.last, secret_parts.last
  end
end
