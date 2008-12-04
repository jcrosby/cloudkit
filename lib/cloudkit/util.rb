module CloudKit
  module Util
    def erb(template, headers={'Content-Type' => 'text/html'}, status=200)
      template_file = open(
        File.join(File.dirname(__FILE__),
        'templates',
        "#{template.to_s}.erb"))
      template = ERB.new(template_file.read)
      [status, headers, [template.result(binding)]]
    end

    def r(method, path, params=[])
      Rack::Router.new(method, path, params)
    end

    def auth_key; 'cloudkit.user'; end
    def auth_presence_key; 'cloudkit.auth'; end
    def challenge_key; 'cloudkit.challenge'; end
    def via_key; 'cloudkit.via'; end
    def flash_key; 'cloudkit.flash'; end
    def oauth_filter_key; 'cloudkit.filter.oauth'; end
    def openid_filter_key; 'cloudkit.filter.openid'; end
    def storage_uri_key; 'cloudkit.storage.uri'; end
    def login_url_key; 'cloudkit.filter.openid.url.login'; end
    def logout_url_key; 'cloudkit.filter.openid.url.logout'; end
  end
end
