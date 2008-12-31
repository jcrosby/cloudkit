$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'test/unit'
require 'shoulda'
require 'rexml/document'

def auth_key; "cloudkit.user"; end
def remote_user; "/cloudkit_users/abcdef"; end

def echo_text(text)
  lambda {|env| [200, {'Content-Type' => 'text/html'}, [text]]}
end

def echo_env(key)
  lambda {|env| [200, {'Content-Type' => 'text/html'}, [env[key] || '']]}
end

def auth
  {auth_key => remote_user}
end

def plain_service
  Rack::Builder.new do
    use Rack::Lint
    use Rack::Config do |env|
      env['cloudkit.storage.uri'] = 'sqlite://service.db'
    end
    use CloudKit::Service, :collections => [:items, :things]
    run echo_text('martino')
  end
end

def authed_service
  Rack::Builder.new do
    use Rack::Lint
    use Rack::Config do |env|
      env['cloudkit.storage.uri'] = 'sqlite://service.db'
      r = CloudKit::Request.new(env)
      r.announce_auth('cloudkit.filter.oauth') # mock
    end
    use CloudKit::Service, :collections => [:items, :things]
    run echo_text('martino')
  end
end

def openid_app
  Rack::Builder.new do
    use Rack::Lint
    use Rack::Session::Pool
    use CloudKit::OpenIDFilter
    run echo_env(auth_key)
  end
end
