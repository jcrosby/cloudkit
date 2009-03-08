$:.unshift File.expand_path(File.dirname(__FILE__)) + '/../lib'
require 'cloudkit'
require 'rexml/document'

TEST_REMOTE_USER = '/cloudkit_users/abcdef'.freeze
VALID_TEST_AUTH = {CLOUDKIT_AUTH_KEY => TEST_REMOTE_USER}.freeze

def echo_text(text)
  lambda {|env| [200, app_headers(text), [text]]}
end

def echo_env(key)
  lambda {|env| [200, app_headers(env[key] || ''), [env[key] || '']]}
end

def app_headers(content)
  {'Content-Type' => 'text/html', 'Content-Length' => content.length.to_s}
end

module CloudKit
  class Janitor
    def clear_store
      CloudKit.storage_adapter.clear
    end
  end
end

JANITOR = CloudKit::Janitor.new
