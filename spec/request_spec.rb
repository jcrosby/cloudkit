require File.dirname(__FILE__) + '/spec_helper'

describe "A Request" do

  it "should match requests with routes" do
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com')).match?('GET', '/').should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/')).match?('GET', '/').should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/')).match?('POST', '/').should_not be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello')).match?('GET', '/hello').should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello')).match?('GET', '/hello').should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello', :method => 'POST')).match?(
        'POST', '/hello').should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q=a', :method => 'POST')).match?(
        'POST', '/hello', [{'q' => 'a'}]).should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q=a', :method => 'POST')).match?(
        'POST', '/hello', ['q']).should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q=a', :method => 'POST')).match?(
        'POST', '/hello', [{'q' => 'b'}]).should_not be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q', :method => 'POST')).match?(
        'POST', '/hello', [{'q' => nil}]).should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q=a', :method => 'POST')).match?(
        'POST', '/hello', [{'q' => nil}]).should_not be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q=a', :method => 'POST')).match?(
        'POST', '/hello', [{'q' => ''}]).should_not be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q&x=y', :method => 'PUT')).match?(
        'PUT', '/hello', ['q', {'x' => 'y'}]).should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q&x=y&z', :method => 'PUT')).match?(
        'PUT', '/hello', ['q', {'x' => 'y'}]).should be_true
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello?q&x=y', :method => 'PUT')).match?(
        'PUT', '/hello', [{'q' => 'a'},{'x' => 'y'}]).should_not be_true
  end

  it "should treat a trailing :id as a wildcard for path matching" do
    Sinatra::Request.new(Rack::MockRequest.env_for(
      'http://example.com/hello/123')).match?('GET', '/hello/:id').should be_true
  end

  it "should inject stack-internal via-style env vars" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/test'))
    request.via.should == []
    request.inject_via('a.b')
    request.via.include?('a.b').should be_true
    request.inject_via('c.d')
    request.via.include?('a.b').should be_true
    request.via.include?('c.d').should be_true
  end

  it "should announce the use of auth middleware" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
    request.via.include?(CLOUDKIT_OAUTH_FILTER_KEY).should be_true
  end

  it "should know if auth provided by upstream middleware" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
    request.using_auth?.should be_true
  end

  it "should know the current user" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.current_user.should be_nil
    request = Sinatra::Request.new(
      Rack::MockRequest.env_for('/', CLOUDKIT_AUTH_KEY => 'cecil'))
    request.current_user.should_not be_nil
    request.current_user.should == 'cecil'
  end

  it "should set the current user" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.current_user = 'cecil'
    request.current_user.should_not be_nil
    request.current_user.should == 'cecil'
  end

  it "should know the login url" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.login_url.should == '/login'
    request = Sinatra::Request.new(
      Rack::MockRequest.env_for('/', CLOUDKIT_LOGIN_URL => '/sessions'))
    request.login_url.should == '/sessions'
  end

  it "should set the login url" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.login_url = '/welcome'
    request.login_url.should == '/welcome'
  end

  it "should know the logout url" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.logout_url.should == '/logout'
    request = Sinatra::Request.new(
      Rack::MockRequest.env_for('/', CLOUDKIT_LOGOUT_URL => '/sessions'))
    request.logout_url.should == '/sessions'
  end

  it "should set the logout url" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.logout_url = '/goodbye'
    request.logout_url.should == '/goodbye'
  end

  it "should get the session" do
    request = Sinatra::Request.new(
      Rack::MockRequest.env_for('/', 'rack.session' => 'this'))
    request.session.should_not be_nil
    request.session.should == 'this'
  end

  it "should know the flash" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
      '/', 'rack.session' => {}))
    request.flash.is_a?(CloudKit::FlashSession).should be_true
  end

  it "should parse if-match headers" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
      '/items/123/versions'))
    request.if_match.should be_nil
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
      '/items/123/versions', 'HTTP_IF_MATCH' => '"a"'))
    request.if_match.should == 'a'
  end

  it "should treat a list of etags in an if-match header as a single etag" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
      '/items/123/versions', 'HTTP_IF_MATCH' => '"a", "b"'))
    # See Sinatra::Request#if_match for more info on this expectation
    request.if_match.should == 'a", "b'
  end

  it "should ignore if-match when set to *" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
      '/items/123/versions', 'HTTP_IF_MATCH' => '*'))
    request.if_match.should be_nil
  end

  it "should understand header auth" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for(
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
    request['oauth_consumer_key'].should == 'dpf43f3p2l4k3l03'
    request['oauth_token'].should == 'nnch734d00sl2jdk'
    request['oauth_timestamp'].should == '1191242096'
    request['oauth_nonce'].should == 'kllo9940pd9333jh'
    request['oauth_signature'].should == 'tR3+Ty81lMeYAr/Fid0kMTYa/WM='
    request['oauth_signature_method'].should == 'HMAC-SHA1'
  end

  it "should know the last path element" do
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/'))
    request.last_path_element.should be_nil
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/abc'))
    request.last_path_element.should == 'abc'
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/abc/'))
    request.last_path_element.should == 'abc'
    request = Sinatra::Request.new(Rack::MockRequest.env_for('/abc/def'))
    request.last_path_element.should == 'def'
  end

end
