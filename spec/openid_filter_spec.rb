require File.dirname(__FILE__) + '/spec_helper'

describe "An OpenIDFilter" do

  before(:each) do
    openid_app = Rack::Builder.new {
      use Rack::Lint
      use Rack::Session::Pool
      use CloudKit::OpenIDFilter, :allow => ['/foo']
      run echo_env(CLOUDKIT_AUTH_KEY)
    }
    @request = Rack::MockRequest.new(openid_app)
  end

  it "should allow root url pass through" do
    response = @request.get('/')
    response.status.should == 200
  end

  it "should allow pass through of URIs defined in :allow" do
    response = @request.get('/foo')
    response.status.should == 200
  end
  
  it "should allow pass through of URIs defined in bypass route callback" do
    openid_app = Rack::Builder.new {
      use Rack::Lint
      use Rack::Session::Pool
      use CloudKit::OpenIDFilter, :allow => ['/foo'] do |url|
        ['/bar'].include? url
      end
      run echo_env(CLOUDKIT_AUTH_KEY)
    }
    request = Rack::MockRequest.new(openid_app)
    response = request.get('/bar')
    response.status.should == 200
  end

  it "should redirect to the login page if authorization is required" do
    response = @request.get('/protected')
    response.status.should == 302
    response['Location'].should == '/login'
  end

  it "should notify downstream nodes of its presence" do
    app = Rack::Builder.new do
      use Rack::Session::Pool
      use CloudKit::OpenIDFilter
      run echo_env(CLOUDKIT_VIA)
    end
    response = Rack::MockRequest.new(app).get('/')
    response.body.should == CLOUDKIT_OPENID_FILTER_KEY
  end

  describe "with upstream authorization middleware" do

    it "should allow pass through if the auth env variable is populated" do
      response = @request.get('/protected', VALID_TEST_AUTH)
      response.status.should == 200
      response.body.should == TEST_REMOTE_USER
    end

    it "should return the auth challenge header" do
      response = @request.get('/protected',
        CLOUDKIT_VIA => CLOUDKIT_OAUTH_FILTER_KEY,
        CLOUDKIT_AUTH_CHALLENGE => {'WWW-Authenticate' => 'etc.'})
      response['WWW-Authenticate'].should_not be_nil
    end

    it "should return a 401 status if authorization is required" do
      response = @request.get('/protected',
        CLOUDKIT_VIA => CLOUDKIT_OAUTH_FILTER_KEY,
        CLOUDKIT_AUTH_CHALLENGE => {'WWW-Authenticate' => 'etc.'})
      response.status.should == 401
    end

  end
end
