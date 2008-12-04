module CloudKit
  class OpenIDFilter
    include Util
    @@lock = Mutex.new
    @@store = nil

    def initialize(app, options={})
      @app = app; @options = options
    end

    def call(env)
      @@lock.synchronize do
        @@store = OpenIDStore.new(env[storage_uri_key])
        @users = UserStore.new(env[storage_uri_key])
        @@store.get_association('x') rescue nil # refresh sqlite3
      end unless @@store
      @request = Request.new(env)
      @request.announce_auth(openid_filter_key)
      case @request
      when r(:get, @request.login_url); request_login
      when r(:post, @request.login_url); begin_openid_login
      when r(:get, '/openid_complete'); complete_openid_login
      when r(:post, @request.logout_url); logout
      else
        if (root_request? || valid_auth_key? || logged_in?)
          @app.call(env)
        else
          if @request.env[challenge_key]
            store_location
            erb(:openid_login, @request.env[challenge_key], 401)
          elsif !@request.via.include?(oauth_filter_key)
            store_location
            login_redirect
          else
            [500, {}, ['server misconfigured']]
          end
        end
      end
    end

    def logout
      user_id = @request.session.delete('user_id')
      result = @users.get(:users, :id => user_id)
      user = result.parsed_content['documents'].first
      user.delete('remember_me_token')
      user.delete('remember_me_expiration')
      user['etag'] = result['Etag']
      json = JSON.generate(users)
      @users.put(:users, :id => user_id, :etag => result['Etag'], :data => json)
      @request.env[auth_key] = nil
      @request.flash['info'] = 'You have been logged out.'
      response = Rack::Response.new([], 302, {'Location' => @request.login_url})
      response.delete_cookie('remember_me')
      response.finish
    end

    def request_login
      erb :openid_login
    end

    def begin_openid_login
      begin
        response = openid_consumer.begin @request[:openid_url]
      rescue => e
        @request.flash[:error] = e
        return login_redirect
      end
      redirect_url = response.redirect_url(base_url, full_url)
      [302, {'Location' => redirect_url}, []]
    end

    def complete_openid_login
      begin
        idp_response = openid_consumer.complete(@request.params, full_url)
      rescue => e
        @request.flash[:error] = e
        return login_redirect
      end
      if idp_response.is_a?(OpenID::Consumer::FailureResponse)
        @request.flash[:error] = idp_response.message
        return login_redirect
      end
      result = @users.get(
        :login_view, :identity_url => idp_response.endpoint.claimed_id)
      users = result.parsed_content['documents']
      if users.empty?
        json = JSON.generate(:identity_url => idp_response.endpoint.claimed_id)
        result = @users.post(:users, :data => json)
        user = result.parsed_content
      else
        user = users.first
      end
      if @request.session['user_id'] = user['id']
        user['remember_me_expiration'] = two_weeks_from_now
        user['remember_me_token'] = Base64.encode64(
          OpenSSL::Random.random_bytes(32)).gsub(/\W/,'')
        url = @request.session.delete('return_to')
        response = Rack::Response.new([], 302, {'Location' => (url || '/')})
        response.set_cookie(
          'remember_me', {
            :value => user['remember_me_token'],
            :expires => Time.at(user['remember_me_expiration']).utc})
        user['etag'] = result['Etag']
        json = JSON.generate(user)
        @users.put(
          :users, :id => user['id'], :etag => result['Etag'], :data => json)
        @request.flash[:notice] = 'You have been logged in.'
        response.finish
      else
        @request.flash[:error] = 'Could not log on with your OpenID.'
        login_redirect
      end
    end

    def login_redirect
      [302, {'Location' => @request.login_url}, []]
    end

    def base_url
      "#{@request.scheme}://#{@request.env['HTTP_HOST']}/"
    end

    def full_url
      base_url + 'openid_complete'
    end

    def logged_in?
      logged_in = user_in_session? || valid_remember_me_token?
      @request.current_user = @request.session['user_id'] if logged_in
      logged_in
    end

    def user_in_session?
      @request.session['user_id'] != nil
    end

    def store_location
      @request.session['return_to'] = @request.url
    end

    def root_request?
      @request.path_info == '/' || @request.path_info == '/favicon.ico'
    end

    def valid_auth_key?
      @request.env[auth_key] && @request.env[auth_key] != ''
    end

    def openid_consumer
      @openid_consumer ||= OpenID::Consumer.new(
        @request.session, OpenIDStore.new)
    end

    def valid_remember_me_token?
      return false unless token = @request.cookies['remember_me']
      result = @users.get(:login_view, :remember_me_token => token)
      return false unless result.status == 200
      users = result.parsed_content
      return false unless users['documents'] && (users['documents'].size == 1)
      user = users['documents'].first
      return false unless Time.now.to_i < user['remember_me_expiration']
      user['remember_me_expiration'] = two_weeks_from_now
      user['etag'] = result['Etag']
      json = JSON.generate(user)
      @users.put(
        :users, :id => user['id'], :etag => result['Etag'], :data => json)
      @request.session['user_id'] = user['id']
      true
    end

    def two_weeks_from_now
      Time.now.to_i+1209600
    end
  end
end
