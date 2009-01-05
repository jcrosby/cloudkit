require 'helper'
class OpenIDFilterTest < Test::Unit::TestCase

  context "An OpenIDFilter" do

    setup do
      openid_app = Rack::Builder.new {
        use Rack::Lint
        use Rack::Session::Pool
        use CloudKit::OpenIDFilter
        run echo_env(CLOUDKIT_AUTH_KEY)
      }
      @request = Rack::MockRequest.new(openid_app)
    end

    should "allow root url pass through" do
      response = @request.get('/')
      assert_equal 200, response.status
    end

    should "redirect to the login page if authorization is required" do
      response = @request.get('/protected')
      assert_equal 302, response.status
      assert_equal '/login', response['Location']
    end

    should "notify downstream nodes of its presence" do
      app = Rack::Builder.new do
        use Rack::Session::Pool
        use CloudKit::OpenIDFilter
        run echo_env(CLOUDKIT_VIA)
      end
      response = Rack::MockRequest.new(app).get('/')
      assert_equal CLOUDKIT_OPENID_FILTER_KEY, response.body
    end

    context "with upstream authorization middleware" do

      should "allow pass through if the auth env variable is populated" do
        response = @request.get('/protected', VALID_TEST_AUTH)
        assert_equal 200, response.status
        assert_equal TEST_REMOTE_USER, response.body
      end

      should "return the auth challenge header" do
        response = @request.get('/protected',
          CLOUDKIT_VIA => CLOUDKIT_OAUTH_FILTER_KEY,
          CLOUDKIT_AUTH_CHALLENGE => {'WWW-Authenticate' => 'etc.'})
        assert response['WWW-Authenticate']
      end

      should "return a 401 status if authorization is required" do
        response = @request.get('/protected',
          CLOUDKIT_VIA => CLOUDKIT_OAUTH_FILTER_KEY,
          CLOUDKIT_AUTH_CHALLENGE => {'WWW-Authenticate' => 'etc.'})
        assert_equal 401, response.status
      end
    end
  end
end
