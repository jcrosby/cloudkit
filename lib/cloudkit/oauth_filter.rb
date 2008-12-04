module CloudKit
  class OAuthFilter
    include Util
    @@lock = Mutex.new
    @@store = nil

    def initialize(app, options={})
      @app = app; @options = options
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      @@lock.synchronize do
        @@store = OAuthStore.new(env[storage_uri_key])
      end unless @@store
      @request = Request.new(env)
      @request.announce_auth(oauth_filter_key)
      return @app.call(env) if @request.path_info == '/'
      begin
        case @request
        when r(:get, '/oauth/meta')
          get_meta
        when r(:post, '/oauth/request_tokens', ['oauth_consumer_key'])
          create_request_token
        when r(:get, '/oauth/authorization', ['oauth_token'])
          request_authorization
        when r(:put, '/oauth/authorized_request_tokens/:id')
          authorize_request_token
        when r(:post, '/oauth/authorized_request_tokens/:id', [{'_method' => 'PUT'}])
          authorize_request_token
        when r(:post, '/oauth/access_tokens')
          create_access_token
        when r(:get, '/oauth')
          get_descriptor
        else
          inject_user_or_challenge
          @app.call(env)
        end
      rescue OAuth::Signature::UnknownSignatureMethod
        # The OAuth spec suggests a 400 status, but serving a 401 with the
        # meta/challenge info seems more appropriate as the oauth metadata
        # specifies the supported signature methods, giving the user agent an
        # opportunity to fix the error.
        return challenge('unknown signature method')
      end
    end

    def create_request_token
      return challenge('invalid nonce') unless valid_nonce?
      (consumer = get_consumer) rescue (return challenge('invalid consumer'))
      signature = OAuth::Signature.build(@request) do
        [nil, consumer['secret']]
      end
      return challenge('invalid signature') unless signature.verify
      token_id, secret = OAuth::Server.new(@request.host).generate_credentials
      request_token = JSON.generate(
        :id           => token_id,
        :secret       => secret,
        :consumer_key => consumer['id'])
      @@store.put(:request_tokens, :id => token_id, :data => request_token)
      [201, {}, ["oauth_token=#{token_id}&oauth_token_secret=#{secret}"]]
    end
    
    def login_redirect
      [302, {'Location' => @request.login_url}, []]
    end

    def request_authorization
      return login_redirect unless @request.current_user
      (request_token = get_request_token) rescue (return challenge('invalid request token'))
      erb :request_authorization
    end

    def authorize_request_token
      return login_redirect unless @request.current_user
      request_token = @@store.get(
        :request_tokens,
        :id => @request.last_path_element).parsed_content
      return challenge('invalid request token') if request_token['authorized_at'] 
      request_token['user_id'] = @request.current_user
      request_token['authorized_at'] = Time.now.httpdate
      json = JSON.generate(request_token)
      @@store.put(
        :request_tokens,
        :id   => request_token['id'],
        :etag => request_token['etag'],
        :data => json)
      erb :authorize_request_token
    end

    def create_access_token
      return challenge('invalid nonce') unless valid_nonce?
      (consumer = get_consumer) rescue (return challenge('invalid consumer'))
      (request_token = get_request_token) rescue (return challenge('invalid request token'))
      unless request_token['consumer_key'] == consumer['id']
        return challenge('invalid consumer')
      end
      signature = OAuth::Signature.build(@request) do
        [request_token['secret'], consumer['secret']]
      end
      return challenge('invalid signature') unless signature.verify
      token_id, secret = OAuth::Server.new(@request.host).generate_credentials
      token_data = JSON.generate(
        :id              => token_id,
        :secret          => secret,
        :consumer_key    => consumer['id'],
        :consumer_secret => consumer['secret'],
        :user_id         => request_token['user_id'])
      @@store.put(:tokens, :id => token_id, :data => token_data)
      @@store.delete(
        :request_tokens,
        :id   => request_token['id'],
        :etag => request_token['etag'])
      [201, {}, ["oauth_token=#{token_id}&oauth_token_secret=#{secret}"]]
    end

    def inject_user_or_challenge
      unless valid_nonce?
        @request.current_user = ''
        inject_challenge
        return
      end
      result = @@store.get(:tokens, :id => @request[:oauth_token])
      access_token = result.parsed_content
      signature = OAuth::Signature.build(@request) do
        [access_token['secret'], access_token['consumer_secret']]
      end
      if signature.verify
        @request.current_user = access_token['user_id']
      else
        @request.current_user = ''
        inject_challenge
      end
    end

    def valid_nonce?
      timestamp = @request[:oauth_timestamp]
      nonce = @request[:oauth_nonce]
      return false unless (timestamp && nonce)
      id = "#{timestamp}:#{nonce}"
      json = JSON.generate(:id => id)
      result = @@store.put(:nonces, :id => id, :data => json)
      return false unless result.status == 201
      true
    end

    def inject_challenge
      @request.env[challenge_key] = challenge_headers
    end

    def challenge(message)
      [401, challenge_headers, [message || '']]
    end

    def challenge_headers
      {
        'WWW-Authenticate' => "OAuth realm=\"http://#{@request.env['HTTP_HOST']}\"",
        'Link' => discovery_link
      }
    end

    def discovery_link
      "<#{@request.scheme}://#{@request.env['HTTP_HOST']}/oauth/meta>; rel=\"http://oauth.net/discovery/1.0/rel/provider\""
    end

    def get_meta
      erb :oauth_meta
    end

    def get_descriptor
      erb :oauth_descriptor
    end

    def get_consumer
      result = @@store.get(:consumers, :id => @request[:oauth_consumer_key])
      raise 'Consumer Not Found' unless result.status == 200
      result.parsed_content
    end

    def get_request_token
      result = @@store.get(:request_tokens, :id => @request[:oauth_token])
      raise 'Request Token Not Found' unless result.status == 200
      result.parsed_content
    end
  end
end
