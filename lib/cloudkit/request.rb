module CloudKit

  # A subclass of Rack::Request providing CloudKit-specific features.
  class Request < Rack::Request
    include CloudKit::Util
    alias_method :cloudkit_params, :params

    def initialize(env)
      super(env)
    end

    # Return a merged set of both standard params and OAuth header params.
    def params
      @cloudkit_params ||= cloudkit_params.merge(oauth_header_params)
    end

    # Return the JSON content from the request body
    def json
      self.body.rewind
      raw = self.body.read
      # extract the json from the body to avoid tunneled _method param from being parsed as json
      (matches = raw.match(/(\{.*\})/)) ? matches[1] : raw
    end

    # Return a CloudKit::URI instance representing the rack request's path info.
    def uri
      @uri ||= CloudKit::URI.new(self.path_info)
    end

    # Return true if method, path, and required_params match.
    def match?(method, path, required_params=[])
      (request_method == method) &&
        path_info.match(path.gsub(':id', '*')) && # just enough to work for now
        param_match?(required_params)
    end

    # Return true of the array of required params match the request params. If
    # a hash in passed in for a param, its value is also used in the match.
    def param_match?(required_params)
      required_params.all? do |required_param|
        case required_param
        when Hash
          key = required_param.keys.first
          return false unless params.has_key? key
          return false unless params[key] == required_param[key]
        when String
          return false unless params.has_key? required_param
        else
          false
        end
        true
      end
    end

    # Return OAuth header params in a hash.
    def oauth_header_params
      # This is a copy of the same method from the OAuth gem.
      # TODO: Refactor the OAuth gem so that this method is available via a
      # mixin, outside of the request proxy context.
      %w( X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION ).each do |header|
        next unless @env.include?(header)
        header = @env[header]
        next unless header[0,6] == 'OAuth '
        oauth_param_string = header[6,header.length].split(/[,=]/)
        oauth_param_string.map!{|v| unescape(v.strip)}
        oauth_param_string.map!{|v| v =~ /^\".*\"$/ ? v[1..-2] : v}
        oauth_params = Hash[*oauth_param_string.flatten]
        oauth_params.reject!{|k,v| k !~ /^oauth_/}
        return oauth_params
      end
      return {}
    end

    # Unescape a value according to the OAuth spec.
    def unescape(value)
      ::URI.unescape(value.gsub('+', '%2B'))
    end

    # Return the last path element in the request URI.
    def last_path_element
      path_element(-1)
    end

    # Return a specific path element
    def path_element(index)
      path_info.split('/')[index] rescue nil
    end

    # Return an array containing one entry for each piece of upstream
    # middleware. This is in the same spirit as Via headers in HTTP, but does
    # not use the header because the transition from one piece of middleware to
    # the next does not use HTTP.
    def via
      @env[CLOUDKIT_VIA].split(', ') rescue []
    end

    # Return parsed contents of an If-Match header.
    #
    # Note: Only a single ETag is useful in the context of CloudKit, so a list
    # is treated as one ETag; the result of using the wrong ETag or a list of
    # ETags is the same in the context of PUT and DELETE where If-Match
    # headers are required.
    def if_match
      etag = @env['HTTP_IF_MATCH']
      return nil unless etag
      etag.strip!
      etag = unquote(etag)
      return nil if etag == '*'
      etag
    end

    # Add a via entry to the Rack environment.
    def inject_via(key)
      items = via << key
      @env[CLOUDKIT_VIA] = items.join(', ')
    end

    # Return the current user URI.
    def current_user
      return nil unless @env[CLOUDKIT_AUTH_KEY] && @env[CLOUDKIT_AUTH_KEY] != ''
      @env[CLOUDKIT_AUTH_KEY]
    end

    # Set the current user URI.
    def current_user=(user)
      @env[CLOUDKIT_AUTH_KEY] = user
    end

    # Return true if authentication is being used.
    def using_auth?
      @env[CLOUDKIT_AUTH_PRESENCE] != nil
    end

    # Report to downstream middleware that authentication is in use.
    def announce_auth(via)
      inject_via(via)
      @env[CLOUDKIT_AUTH_PRESENCE] = 1
    end

    # Return the session associated with this request.
    def session
      @env['rack.session']
    end

    # Return the login URL for this request. This is stashed in the Rack
    # environment so the OpenID and OAuth middleware can cooperate during the
    # token authorization step in the OAuth flow.
    def login_url
      @env[CLOUDKIT_LOGIN_URL] || '/login'
    end

    # Set the login url for this request.
    def login_url=(url)
      @env[CLOUDKIT_LOGIN_URL] = url
    end

    # Return the logout URL for this request.
    def logout_url
      @env[CLOUDKIT_LOGOUT_URL] || '/logout'
    end

    # Set the logout URL for this request.
    def logout_url=(url)
      @env[CLOUDKIT_LOGOUT_URL] = url
    end

    # Return the flash session for this request.
    def flash
      session[CLOUDKIT_FLASH] ||= CloudKit::FlashSession.new
    end
  end
end
