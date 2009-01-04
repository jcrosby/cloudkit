$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'test/unit'
require 'shoulda'
require 'rexml/document'

TEST_REMOTE_USER = '/cloudkit_users/abcdef'.freeze
VALID_TEST_AUTH = {CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER}.freeze

def echo_text(text)
  lambda {|env| [200, {'Content-Type' => 'text/html'}, [text]]}
end

def echo_env(key)
  lambda {|env| [200, {'Content-Type' => 'text/html'}, [env[key] || '']]}
end

def plain_service
  Rack::Builder.new do
    use Rack::Lint
    use Rack::Config do |env|
      env[CLOUDKIT_STORAGE_URI] = 'sqlite://service.db'
    end
    use CloudKit::Service, :collections => [:items, :things]
    run echo_text('martino')
  end
end

def authed_service
  Rack::Builder.new do
    use Rack::Lint
    use Rack::Config do |env|
      env[CLOUDKIT_STORAGE_URI] = 'sqlite://service.db'
      r = CloudKit::Request.new(env)
      r.announce_auth(CLOUDKIT_OAUTH_FILTER_KEY) # mock
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
    run echo_env(CLOUDKIT_AUTH_KEY)
  end
end
