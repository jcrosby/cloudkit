module CloudKit
  module Util

    # Render ERB content
    def erb(request, template, headers={'Content-Type' => 'text/html'}, status=200)
      template_file = open(
        File.join(File.dirname(__FILE__),
        'templates',
        "#{template.to_s}.erb"))
      template = ERB.new(template_file.read)
      [status, headers, [template.result(binding)]]
    end

    # Build a Rack::Router instance
    def r(method, path, params=[])
      Rack::Router.new(method, path, params)
    end

    # Remove the outer double quotes from a given string.
    def unquote(text)
      (text =~ /^\".*\"$/) ? text[1..-2] : text
    end

    # Return the key used to store the authenticated user.
    def auth_key; 'cloudkit.user'; end
    
    # Return the key used to indicate the presence of auth in a stack.
    def auth_presence_key; 'cloudkit.auth'; end
    
    # Return the key used to store auth challenge headers shared between
    # OpenID and OAuth middleware.
    def challenge_key; 'cloudkit.challenge'; end
    
    # Return the 'via' key used to announce and track upstream middleware.
    def via_key; 'cloudkit.via'; end
    
    # Return the key used to store the 'flash' in the session.
    def flash_key; 'cloudkit.flash'; end
    
    # Return the 'via' key for the OAuth filter.
    def oauth_filter_key; 'cloudkit.filter.oauth'; end
    
    # Return the 'via' key for the OpenID filter.
    def openid_filter_key; 'cloudkit.filter.openid'; end
    
    # Return the key used to store the shared storage URI for the stack.
    def storage_uri_key; 'cloudkit.storage.uri'; end
    
    # Return the key for the login URL used in OpenID and OAuth middleware
    # components.
    def login_url_key; 'cloudkit.filter.openid.url.login'; end
    
    # Return the key for the logout URL used in OpenID and OAuth middleware
    # components.
    def logout_url_key; 'cloudkit.filter.openid.url.logout'; end
    
    # Return the outer namespace key for the JSON store.
    def store_key; :cloudkit_json_store; end
  end
end
