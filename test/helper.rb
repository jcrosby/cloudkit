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
