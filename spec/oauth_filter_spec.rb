require File.dirname(__FILE__) + '/spec_helper'

describe "An OAuthFilter" do

  before(:each) do
    CloudKit.setup_storage_adapter unless CloudKit.storage_adapter
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

  after(:each) do
    CloudKit.storage_adapter.clear
    @store.load_static_consumer
  end

  it "should verify signatures" do
    response = do_get
    response.status.should == 200
    response.body.should == 'martino'
  end

  it "should notify downstream nodes of its presence" do
    app = CloudKit::OAuthFilter.new(echo_env(CLOUDKIT_VIA))
    response = Rack::MockRequest.new(app).get('/')
    response.body.should == CLOUDKIT_OAUTH_FILTER_KEY
  end

  it "should not allow a nonce/timestamp combination to appear twice" do
    do_get
    response = do_get
    response.body.should == ''
    get_request_token
    response = get_request_token
    response.status.should == 401
  end

  it "should add the remote user to the rack environment for verified requests" do
    response = do_get
    response.body.should == 'martino'
  end

  it "should allow requests for / to pass through" do
    response = Rack::MockRequest.new(@oauth_filtered_app).get('/')
    response.status.should == 200
  end

  it "should reject unauthorized requests" do
    response = Rack::MockRequest.new(@oauth_filtered_app).get(
      'http://photos.example.net/photos?file=vacation.jpg&size=original' +
      '&oauth_version=1.0' +
      '&oauth_consumer_key=dpf43f3p2l4k3l03' +
      '&oauth_token=nnch734d00sl2jdk' +
      '&oauth_timestamp=1191242096' +
      '&oauth_nonce=kllo9940pd9333jh' +
      '&oauth_signature=fail'+
      '&oauth_signature_method=HMAC-SHA1', 'X-Remote-User' => 'intruder') # TODO rework
    response.body.should == ''
  end

  describe "supporting OAuth Discovery" do

    it "should set the auth challenge for unauthorized requests" do
      app = CloudKit::OAuthFilter.new(
        lambda {|env| [200, {}, [env[CLOUDKIT_AUTH_CHALLENGE]['WWW-Authenticate'] || '']]})
      response = Rack::MockRequest.new(app).get(
        '/items', 'HTTP_HOST' => 'example.org')
      response.body.should == 'OAuth realm="http://example.org"'
      app = CloudKit::OAuthFilter.new(
        lambda {|env| [200, {}, [env[CLOUDKIT_AUTH_CHALLENGE]['Link'] || '']]})
      response = Rack::MockRequest.new(app).get(
        '/items', 'HTTP_HOST' => 'example.org')
      response.body.should == '<http://example.org/oauth/meta>; rel="http://oauth.net/discovery/1.0/rel/provider"'
    end

    it "should provide XRD metadata on GET /oauth/meta" do
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        '/oauth/meta', 'HTTP_HOST' => 'example.org')
      response.status.should == 200
      doc = REXML::Document.new(response.body)
      REXML::XPath.first(doc, '//XRD/Type').should_not be_nil
      REXML::XPath.first(doc, '//XRD/Type').children[0].to_s.should == 'http://oauth.net/discovery/1.0'
      REXML::XPath.first(doc, '//XRD/Service/Type').should_not be_nil
      REXML::XPath.first(doc, '//XRD/Service/Type').children[0].to_s.should == 'http://oauth.net/discovery/1.0/rel/provider'
      REXML::XPath.first(doc, '//XRD/Service/URI').should_not be_nil
      REXML::XPath.first(doc, '//XRD/Service/URI').children[0].to_s.should == 'http://example.org/oauth'
    end

    it "should respond to OAuth Discovery Draft 2 / XRDS-Simple Discovery" do
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        '/anything',
        'HTTP_HOST'   => 'example.org',
        'HTTP_ACCEPT' => 'application/xrds+xml')
      response.status.should == 200
      response['X-XRDS-Location'].should == 'http://example.org/oauth'
    end

    it "should provide a descriptor document on GET /oauth" do
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        '/oauth', 'HTTP_HOST' => 'example.org')
      response.status.should == 200
      response['Content-Type'].should == 'application/xrds+xml'
    end

    it "should populate the static consumer on startup" do
      response = @store.get('/cloudkit_oauth_consumers/cloudkitconsumer')
      response.status.should == 200
    end

  end

  describe "supporting authorization" do

    it "should generate request tokens" do
      response = get_request_token
      response.status.should == 201
      token, secret = response.body.split('&')
      token_parts = token.split('=')
      secret_parts = secret.split('=')
      token_parts.first.should == 'oauth_token'
      secret_parts.first.should == 'oauth_token_secret'
      token_parts.last.should_not be_nil
      token_parts.last.should_not be_empty
      secret_parts.last.should_not be_nil
      secret_parts.last.should_not be_empty
    end

    it "should not generate request tokens for invalid consumers" do  
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
      response.status.should == 401
    end

    it "should store request tokens for authorizaton" do
      response = get_request_token
      response.status.should == 201
      token, secret = extract_token(response)
      request_token = @store.get("/cloudkit_oauth_request_tokens/#{token}").parsed_content
      request_token.should_not be_nil
      request_token['secret'].should == secret
      request_token['authorized_at'].should be_nil
    end

    it "should redirect to login before allowing GET requests for request token authorization" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        "/oauth/authorization?oauth_token=#{token}")
      response.status.should == 302
      response['Location'].should == '/login'
    end

    it "should respond successfully to authorization GET requests for logged-in users with a valid request token" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        "/oauth/authorization?oauth_token=#{token}", VALID_TEST_AUTH)
      response.status.should == 200
    end

    it "should reject authorization GET requests with invalid tokens" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).get(
        "/oauth/authorization?oauth_token=fail", VALID_TEST_AUTH)
      response.status.should == 401
    end

    it "should authorize request tokens for verified requests" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).put(
        "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
      response.status.should == 200
      request_token = @store.get("/cloudkit_oauth_request_tokens/#{token}").parsed_content
      request_token['authorized_at'].should_not be_nil
      request_token['user_id'].should_not be_nil
    end

    it "should removed denied request tokens" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).put(
        "/oauth/authorized_request_tokens/#{token}?submit=Deny", VALID_TEST_AUTH)
      response.status.should == 200
      response = @store.get("/cloudkit_oauth_request_tokens/#{token}")
      response.status.should == 410
    end

    it "should redirect to login for authorization PUT requests unless logged-in" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).put(
        "/oauth/authorized_request_tokens/#{token}?submit=Approve")
      response.status.should == 302
      response['Location'].should == '/login'
    end

    it "should not create access tokens for request tokens that have already been authorized" do
      response = get_request_token
      token, secret = extract_token(response)
      response = Rack::MockRequest.new(@oauth_filtered_app).put(
        "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
      response.status.should == 200
      response = Rack::MockRequest.new(@oauth_filtered_app).put(
        "/oauth/authorized_request_tokens/#{token}?submit=Approve", VALID_TEST_AUTH)
      response.status.should == 401
    end

    it "should provide access tokens in exchange for authorized request tokens" do
      response = get_access_token
      response.status.should == 201
      token, secret = extract_token(response)
      token.should_not be_empty
      secret.should_not be_empty
    end

    it "should remove request tokens after creating access tokens" do
      response = get_access_token
      response.status.should == 201
      request_tokens = @store.get('/cloudkit_oauth_request_tokens').parsed_content
      request_tokens['total'].should == 0
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
  response.status.should == 200
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
