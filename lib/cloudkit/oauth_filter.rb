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
  class OAuthFilter < Sinatra::Base
    include Util

    configure do
      @@lock  = Mutex.new
      @@store = nil
    end

    before do
      @@lock.synchronize do
        @@store = OAuthStore.new(env[CLOUDKIT_STORAGE_URI])
      end unless @@store

      @request.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY)
      halt xrds_location if oauth_disco_draft2_xrds?
      forward if @request.path_info == '/'

      load_user_from_session
    end

    def store; @@store; end

    #
    # Create a new Request Token
    #
    post '/oauth/request_tokens' do
      validate_nonce!
      consumer  = get_consumer
      validate_signature(consumer['secret'])
      token_id, secret = OAuth::Server.new(@request.host).generate_credentials
      request_token = JSON.generate(
        :secret       => secret,
        :consumer_key => params[:oauth_consumer_key])
      @@store.put(
        "/cloudkit_oauth_request_tokens/#{token_id}",
        :json => request_token)
      Rack::Response.new("oauth_token=#{token_id}&oauth_token_secret=#{secret}", 201).finish
    end

    #
    # Get a form requesting the user's authorization of a request token
    #
    get '/oauth/authorization' do
      validate_current_user

      request_token_result = @@store.get(
        "/cloudkit_oauth_request_tokens/#{params[:oauth_token]}")
      unless request_token_result.status == 200
        halt challenge('invalid request token')
      end

      request_token = request_token_result.parsed_content
      erb(@request, :request_authorization)
    end

    #
    # Authorize or Deny a Request Token
    #
    put '/oauth/authorized_request_tokens/:id' do
      # Temporarily relying on a button value until pluggable templates are
      # introduced in 1.0.
      validate_current_user
      halt deny_request_token if params[:submit] == 'Deny'

      request_token_response = @@store.get(
        "/cloudkit_oauth_request_tokens/#{params[:id]}")
      request_token = request_token_response.parsed_content
      if request_token['authorized_at']
        halt challenge('invalid request token')
      end

      request_token['user_id']       = @request.current_user
      request_token['authorized_at'] = Time.now.httpdate
      json                           = JSON.generate(request_token)
      @@store.put(
        "/cloudkit_oauth_request_tokens/#{params[:id]}",
        :etag => request_token_response.etag,
        :json => json)
      erb(@request, :authorize_request_token)
    end

    #
    # Create an Access Token
    #
    post '/oauth/access_tokens' do
      validate_nonce!
      consumer = get_consumer
      request_token_response = @@store.get(
        "/cloudkit_oauth_request_tokens/#{params[:oauth_token]}")
      unless request_token_response.status == 200
        halt challenge('invalid request token')
      end

      request_token = request_token_response.parsed_content
      unless request_token['consumer_key'] == params[:oauth_consumer_key]
        halt challenge('invalid consumer')
      end

      validate_signature(consumer['secret'], request_token['secret'])
      token_id, secret = OAuth::Server.new(@request.host).generate_credentials
      token_data = JSON.generate(
        :secret          => secret,
        :consumer_key    => params[:oauth_consumer_key],
        :consumer_secret => consumer['secret'],
        :user_id         => request_token['user_id'])
      @@store.put(
        "/cloudkit_oauth_tokens/#{token_id}",
        :json => token_data)
      @@store.delete(
        "/cloudkit_oauth_request_tokens/#{params[:oauth_token]}",
        :etag => request_token_response.etag)
      Rack::Response.new("oauth_token=#{token_id}&oauth_token_secret=#{secret}", 201).finish
    end

    #
    # Return the location of the OAuth Provider description
    #
    get '/oauth/meta' do
      # Expected in next OAuth Discovery Draft
      erb(@request, :oauth_meta)
    end

    #
    # Describe this OAuth Provider
    #
    get '/oauth' do
      erb(@request, :oauth_descriptor, {'Content-Type' => 'application/xrds+xml'})
    end

    #
    # For all other requests, inject user information or challenge headers
    #
    get '/*' do
      inject_user_or_challenge
      forward
    end

    def validate_current_user
      halt login_redirect unless @request.current_user
    end

    def validate_signature(consumer_secret, token_secret=nil)
      signature = build_oauth_signature(consumer_secret, token_secret)
      halt challenge('invalid signature') unless signature.verify
    end

    def get_consumer
      consumer_result = @@store.get(
        "/cloudkit_oauth_consumers/#{params[:oauth_consumer_key]}")
      halt challenge('invalid consumer') unless consumer_result.status == 200
      consumer_result.parsed_content
    end

    def deny_request_token
      request_token_response = @@store.get(
        "/cloudkit_oauth_request_tokens/#{params[:id]}")
      @@store.delete(
        "/cloudkit_oauth_request_tokens/#{params[:id]}",
        :etag => request_token_response.etag)
      erb(@request, :request_token_denied)
    end

    def inject_user_or_challenge
      unless valid_nonce?
        @request.current_user = ''
        inject_challenge
        return
      end

      access_token = @@store.get(
        "/cloudkit_oauth_tokens/#{params[:oauth_token]}").parsed_content
      signature = build_oauth_signature(access_token['consumer_secret'], access_token['secret'])
      if signature.verify
        @request.current_user = access_token['user_id']
      else
        @request.current_user = ''
        inject_challenge
      end
    end

    def validate_nonce!
      halt challenge('invalid nonce') unless valid_nonce?
    end

    def valid_nonce?
      timestamp = params[:oauth_timestamp]
      nonce     = params[:oauth_nonce]
      return false unless (timestamp && nonce)

      uri    = "/cloudkit_oauth_nonces/#{timestamp},#{nonce}"
      result = @@store.put(uri, :json => '{}')
      return false unless result.status == 201

      true
    end

    def inject_challenge
      @request.env[CLOUDKIT_AUTH_CHALLENGE] = challenge_headers
    end

    def challenge(message='')
      Rack::Response.new(message, 401, challenge_headers).finish
    end

    def challenge_headers
      {
        'WWW-Authenticate' => "OAuth realm=\"http://#{@request.env['HTTP_HOST']}\"",
        'Link'             => discovery_link,
        'Content-Type'     => 'application/json'
      }
    end

    def discovery_link
      "<#{@request.scheme}://#{@request.env['HTTP_HOST']}/oauth/meta>; rel=\"http://oauth.net/discovery/1.0/rel/provider\""
    end

    def login_redirect
      @request.session['return_to'] = @request.url if @request.session
      Rack::Response.new([], 302, {'Location' => @request.login_url}).finish
    end

    def load_user_from_session
      @request.current_user = @request.session['user_uri'] if @request.session
    end

    def oauth_disco_draft2_xrds?
      # Current OAuth Discovery Draft 2 / XRDS-Simple 1.0, Section 5.1.2
      @request.get? &&
        @request.env['HTTP_ACCEPT'] &&
        @request.env['HTTP_ACCEPT'].match(/application\/xrds\+xml/)
    end

    def xrds_location
      # Current OAuth Discovery Draft 2 / XRDS-Simple 1.0, Section 5.1.2
      Rack::Response.new([], 200, {'X-XRDS-Location' => "#{@request.scheme}://#{@request.env['HTTP_HOST']}/oauth"}).finish
    end

    def build_oauth_signature(consumer_secret, token_secret=nil)
      begin
        OAuth::Signature.build(@request) { [token_secret, consumer_secret] }
      rescue OAuth::Signature::UnknownSignatureMethod
        # The OAuth spec suggests a 400 status, but serving a 401 with the
        # meta/challenge info seems more appropriate as the OAuth metadata
        # specifies the supported signature methods, giving the user agent an
        # opportunity to fix the error.
        halt challenge('unknown signature method')
      end
    end
  end
end
