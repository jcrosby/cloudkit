module CloudKit

  # An OpenIDFilter provides OpenID authentication, listening for upstream
  # OAuth authentication and bypassing if already authorized.
  #
  # The root URI, "/", is always bypassed. More URIs can also be bypassed using
  # the :allow option:
  #
  #   use OpenIDFilter, :allow => ['/foo', '/bar']
  #
  # Responds to the following URIs:
  #   /login
  #   /logout
  #   /openid_complete
  #
  class OpenIDFilter
    include Util

    @@lock  = Mutex.new
    @@store = nil

    def initialize(app, options={}, &bypass_route_callback)
      @app     = app
      @options = options
      @bypass_route_callback = bypass_route_callback || Proc.new {|url| url == '/'}
    end

    def call(env)
      @@lock.synchronize do
        @@store = OpenIDStore.new
        @users  = UserStore.new
      end unless @@store

      request = Request.new(env)
      request.announce_auth(CLOUDKIT_OPENID_FILTER_KEY)

      case request
      when r(:get, request.login_url); request_login(request)
      when r(:post, request.login_url); begin_openid_login(request)
      when r(:get, '/openid_complete'); complete_openid_login(request)
      when r(:post, request.logout_url); logout(request)
      else
        if bypass?(request)
          @app.call(env)
        else
          if request.env[CLOUDKIT_AUTH_CHALLENGE]
            store_location(request)
            erb(
              request,
              :openid_login,
              request.env[CLOUDKIT_AUTH_CHALLENGE].merge('Content-Type' => 'text/html'),
              401)
          elsif !request.via.include?(CLOUDKIT_OAUTH_FILTER_KEY)
            store_location(request)
            login_redirect(request)
          else
            Rack::Response.new('server misconfigured', 500).finish
          end
        end
      end
    end

    def logout(request)
      user_uri = request.session.delete('user_uri')
      result   = @users.get(user_uri)
      user     = result.parsed_content
      user.delete('remember_me_token')
      user.delete('remember_me_expiration')
      json = JSON.generate(user)
      @users.put(user_uri, :etag => result.etag, :json => json)

      request.env[CLOUDKIT_AUTH_KEY] = nil
      request.flash['info'] = 'You have been logged out.'
      response = Rack::Response.new(
        [],
        302,
        {'Location' => request.login_url, 'Content-Type' => 'text/html'})
      response.delete_cookie('remember_me')
      response.finish
    end

    def request_login(request)
      erb(request, :openid_login)
    end

    def begin_openid_login(request)
      begin
        response = openid_consumer(request).begin(request[:openid_url])
      rescue => e
        request.flash[:error] = e
        return login_redirect(request)
      end

      redirect_url = response.redirect_url(base_url(request), full_url(request))
      Rack::Response.new([], 302, {'Location' => redirect_url}).finish
    end

    def complete_openid_login(request)
      begin
        idp_response = openid_consumer(request).complete(request.params, full_url(request))
      rescue => e
        request.flash[:error] = e
        return login_redirect(request)
      end

      if idp_response.is_a?(OpenID::Consumer::FailureResponse)
        request.flash[:error] = idp_response.message
        return login_redirect(request)
      end

      result = @users.get(
        '/cloudkit_users',
        # '/cloudkit_login_view',
        :identity_url => idp_response.endpoint.claimed_id)
      user_uris = result.parsed_content['uris']

      if user_uris.empty?
        json     = JSON.generate(:identity_url => idp_response.endpoint.claimed_id)
        result   = @users.post('/cloudkit_users', :json => json)
        user_uri = result.parsed_content['uri']
      else
        user_uri = user_uris.first
      end
      user_result = @users.resolve_uris([user_uri]).first
      user        = user_result.parsed_content

      if request.session['user_uri'] = user_uri
        request.current_user = user_uri
        user['remember_me_expiration'] = two_weeks_from_now
        user['remember_me_token'] = Base64.encode64(
          OpenSSL::Random.random_bytes(32)).gsub(/\W/,'')
        url      = request.session.delete('return_to')
        response = Rack::Response.new(
          [],
          302,
          {'Location' => (url || '/'), 'Content-Type' => 'text/html'})
        response.set_cookie(
          'remember_me', {
            :value   => user['remember_me_token'],
            :expires => Time.at(user['remember_me_expiration']).utc})
        json = JSON.generate(user)
        @users.put(user_uri, :etag => user_result.etag, :json => json)
        request.flash[:notice] = 'You have been logged in.'
        response.finish
      else
        request.flash[:error] = 'Could not log on with your OpenID.'
        login_redirect(request)
      end
    end

    def login_redirect(request)
      Rack::Response.new([], 302, {'Location' => request.login_url}).finish
    end

    def base_url(request)
      "#{request.scheme}://#{request.env['HTTP_HOST']}/"
    end

    def full_url(request)
      base_url(request) + 'openid_complete'
    end

    def logged_in?(request)
      logged_in = user_in_session?(request) || valid_remember_me_token?(request)
      request.current_user = request.session['user_uri'] if logged_in
      logged_in
    end

    def user_in_session?(request)
      request.session['user_uri'] != nil
    end

    def store_location(request)
      request.session['return_to'] = request.url
    end

    def root_request?(request)
      request.path_info == '/' || request.path_info == '/favicon.ico'
    end

    def valid_auth_key?(request)
      request.env[CLOUDKIT_AUTH_KEY] && request.env[CLOUDKIT_AUTH_KEY] != ''
    end

    def openid_consumer(request)
      @openid_consumer ||= OpenID::Consumer.new(
        request.session, OpenIDStore.new)
    end

    def valid_remember_me_token?(request)
      return false unless token = request.cookies['remember_me']

      # result = @users.get('/cloudkit_login_view', :remember_me_token => token)
      result = @users.get('/cloudkit_users', :remember_me_token => token)
      return false unless result.status == 200

      user_uris = result.parsed_content['uris']
      return false unless user_uris.try(:size) == 1

      user_uri    = user_uris.first
      user_result = @users.resolve_uris([user_uri]).first
      user        = user_result.parsed_content
      return false unless Time.now.to_i < user['remember_me_expiration']

      user['remember_me_expiration'] = two_weeks_from_now
      json = JSON.generate(user)
      @users.put(user_uri, :etag => user_result.etag, :json => json)
      request.session['user_uri'] = user_uri
      true
    end

    def two_weeks_from_now
      Time.now.to_i+1209600
    end

    def allow?(uri)
      @bypass_route_callback.call(uri) || 
        @options[:allow] && @options[:allow].include?(uri)
    end

    def bypass?(request)
      allow?(request.path_info) ||
        valid_auth_key?(request) ||
        logged_in?(request)
    end
  end
end
