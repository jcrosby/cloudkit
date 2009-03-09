module CloudKit
  
  # An OAuthFilter provides both OAuth 1.0 support, plus OAuth Discovery.
  #
  # Responds to the following URIs as part of the OAuth 1.0 "dance":
  #
  #   /oauth/request_tokens
  #   /oauth/authorization
  #   /oauth/authorized_request_tokens/{id}
  #   /oauth/access_tokens
  #
  # Responds to the following URIs are part of OAuth Discovery:
  #   /oauth
  #   /oauth/meta
  #
  # See also:
  # - {OAuth Core 1.0}[http://oauth.net/core/1.0]
  # - {OAuth Discovery}[http://oauth.net/discovery]
  # - Thread[http://groups.google.com/group/oauth/browse_thread/thread/29a1b550396f63cf] covering /oauth and /oauth/meta URIs.
  #
  class OAuthFilter
    include Util

    @@lock  = Mutex.new
    @@store = nil

    def initialize(app, options={})
      @app     = app
      @options = options
    end

    def call(env)
      @@lock.synchronize do
        @@store = OAuthStore.new
      end unless @@store

      request = Request.new(env)
      request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
      return xrds_location(request) if oauth_disco_draft2_xrds?(request)
      return @app.call(env) if request.path_info == '/'

      load_user_from_session(request)

      begin
        case request
        when r(:get, '/oauth/meta')
          get_meta(request)
        when r(:post, '/oauth/request_tokens', ['oauth_consumer_key'])
          create_request_token(request)
        when r(:get, '/oauth/authorization', ['oauth_token'])
          request_authorization(request)
        when r(:put, '/oauth/authorized_request_tokens/:id', ['submit' => 'Approve'])
          # Temporarily relying on a button value until pluggable templates are
          # introduced in 1.0.
          authorize_request_token(request)
        when r(:put, '/oauth/authorized_request_tokens/:id', ['submit' => 'Deny'])
          # See previous comment.
          deny_request_token(request)
        when r(:post, '/oauth/authorized_request_tokens/:id', [{'_method' => 'PUT'}])
          authorize_request_token(request)
        when r(:post, '/oauth/access_tokens')
          create_access_token(request)
        when r(:get, '/oauth')
          get_descriptor(request)
        else
          inject_user_or_challenge(request)
          @app.call(env)
        end
      rescue OAuth::Signature::UnknownSignatureMethod
        # The OAuth spec suggests a 400 status, but serving a 401 with the
        # meta/challenge info seems more appropriate as the OAuth metadata
        # specifies the supported signature methods, giving the user agent an
        # opportunity to fix the error.
        return challenge(request, 'unknown signature method')
      end
    end

    def store; @@store; end

    protected

    def create_request_token(request)
      return challenge(request, 'invalid nonce') unless valid_nonce?(request)

      consumer_result = @@store.get("/cloudkit_oauth_consumers/#{request[:oauth_consumer_key]}")
      unless consumer_result.status == 200
        return challenge(request, 'invalid consumer')
      end

      consumer  = consumer_result.parsed_content
      signature = OAuth::Signature.build(request) { [nil, consumer['secret']] }
      return challenge(request, 'invalid signature') unless signature.verify

      token_id, secret = OAuth::Server.new(request.host).generate_credentials
      request_token = JSON.generate(
        :secret       => secret,
        :consumer_key => request[:oauth_consumer_key])
      @@store.put(
        "/cloudkit_oauth_request_tokens/#{token_id}",
        :json => request_token)
      Rack::Response.new("oauth_token=#{token_id}&oauth_token_secret=#{secret}", 201).finish
    end

    def request_authorization(request)
      return login_redirect(request) unless request.current_user

      request_token_result = @@store.get("/cloudkit_oauth_request_tokens/#{request[:oauth_token]}")
      unless request_token_result.status == 200
        return challenge(request, 'invalid request token')
      end

      request_token = request_token_result.parsed_content
      erb(request, :request_authorization)
    end

    def authorize_request_token(request)
      return login_redirect(request) unless request.current_user

      request_token_response = @@store.get("/cloudkit_oauth_request_tokens/#{request.last_path_element}")
      request_token = request_token_response.parsed_content
      if request_token['authorized_at']
        return challenge(request, 'invalid request token')
      end

      request_token['user_id']       = request.current_user
      request_token['authorized_at'] = Time.now.httpdate
      json                           = JSON.generate(request_token)
      @@store.put(
        "/cloudkit_oauth_request_tokens/#{request.last_path_element}",
        :etag => request_token_response.etag,
        :json => json)
      erb(request, :authorize_request_token)
    end

    def deny_request_token(request)
      return login_redirect(request) unless request.current_user

      request_token_response = @@store.get("/cloudkit_oauth_request_tokens/#{request.last_path_element}")
      @@store.delete(
        "/cloudkit_oauth_request_tokens/#{request.last_path_element}",
        :etag => request_token_response.etag)
      erb(request, :request_token_denied)
    end

    def create_access_token(request)
      return challenge(request, 'invalid nonce') unless valid_nonce?(request)

      consumer_response = @@store.get("/cloudkit_oauth_consumers/#{request[:oauth_consumer_key]}")
      unless consumer_response.status == 200
        return challenge(request, 'invalid consumer')
      end

      consumer = consumer_response.parsed_content
      request_token_response = @@store.get("/cloudkit_oauth_request_tokens/#{request[:oauth_token]}")
      unless request_token_response.status == 200
        return challenge(request, 'invalid request token')
      end

      request_token = request_token_response.parsed_content
      unless request_token['consumer_key'] == request[:oauth_consumer_key]
        return challenge(request, 'invalid consumer')
      end

      signature = OAuth::Signature.build(request) do
        [request_token['secret'], consumer['secret']]
      end
      unless signature.verify
        return challenge(request, 'invalid signature')
      end

      token_id, secret = OAuth::Server.new(request.host).generate_credentials
      token_data = JSON.generate(
        :secret          => secret,
        :consumer_key    => request[:oauth_consumer_key],
        :consumer_secret => consumer['secret'],
        :user_id         => request_token['user_id'])
      @@store.put("/cloudkit_oauth_tokens/#{token_id}", :json => token_data)
      @@store.delete(
        "/cloudkit_oauth_request_tokens/#{request[:oauth_token]}",
        :etag => request_token_response.etag)
      Rack::Response.new("oauth_token=#{token_id}&oauth_token_secret=#{secret}", 201).finish
    end

    def inject_user_or_challenge(request)
      unless valid_nonce?(request)
        request.current_user = ''
        inject_challenge(request)
        return
      end

      result       = @@store.get("/cloudkit_oauth_tokens/#{request[:oauth_token]}")
      access_token = result.parsed_content
      signature    = OAuth::Signature.build(request) do
        [access_token['secret'], access_token['consumer_secret']]
      end
      if signature.verify
        request.current_user = access_token['user_id']
      else
        request.current_user = ''
        inject_challenge(request)
      end
    end

    def valid_nonce?(request)
      timestamp = request[:oauth_timestamp]
      nonce     = request[:oauth_nonce]
      return false unless (timestamp && nonce)

      uri    = "/cloudkit_oauth_nonces/#{timestamp},#{nonce}"
      result = @@store.put(uri, :json => '{}')
      return false unless result.status == 201

      true
    end

    def inject_challenge(request)
      request.env[CLOUDKIT_AUTH_CHALLENGE] = challenge_headers(request)
    end

    def challenge(request, message='')
      Rack::Response.new(message, 401, challenge_headers(request)).finish
    end

    def challenge_headers(request)
      {
        'WWW-Authenticate' => "OAuth realm=\"http://#{request.env['HTTP_HOST']}\"",
        'Link' => discovery_link(request),
        'Content-Type' => 'application/json'
      }
    end

    def discovery_link(request)
      "<#{request.scheme}://#{request.env['HTTP_HOST']}/oauth/meta>; rel=\"http://oauth.net/discovery/1.0/rel/provider\""
    end

    def login_redirect(request)
      request.session['return_to'] = request.url if request.session
      Rack::Response.new([], 302, {'Location' => request.login_url}).finish
    end

    def load_user_from_session(request)
      request.current_user = request.session['user_uri'] if request.session
    end

    def get_meta(request)
      # Expected in next OAuth Discovery Draft
      erb(request, :oauth_meta)
    end

    def oauth_disco_draft2_xrds?(request)
      # Current OAuth Discovery Draft 2 / XRDS-Simple 1.0, Section 5.1.2
      request.get? &&
        request.env['HTTP_ACCEPT'] &&
        request.env['HTTP_ACCEPT'].match(/application\/xrds\+xml/)
    end

    def xrds_location(request)
      # Current OAuth Discovery Draft 2 / XRDS-Simple 1.0, Section 5.1.2
      Rack::Response.new([], 200, {'X-XRDS-Location' => "#{request.scheme}://#{request.env['HTTP_HOST']}/oauth"}).finish
    end

    def get_descriptor(request)
      erb(request, :oauth_descriptor, {'Content-Type' => 'application/xrds+xml'})
    end
  end
end
