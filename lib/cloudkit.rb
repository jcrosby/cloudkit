require 'rubygems'
require 'erb'
require 'json'
require 'md5'
require 'openid'
gem 'sequel', '=2.6.0'
require 'sequel'
require 'time'
require 'uuid'
require 'rack'
require 'rack/config'
require 'oauth'
require 'oauth/consumer'
require 'oauth/request_proxy/rack_request'
require 'oauth/server'
require 'oauth/signature'
require 'cloudkit/constants'
require 'cloudkit/util'
require 'cloudkit/store/adapter'
require 'cloudkit/store/extraction_view'
require 'cloudkit/store/response'
require 'cloudkit/store/response_helpers'
require 'cloudkit/store/sql_adapter'
require 'cloudkit/store'
require 'cloudkit/flash_session'
require 'cloudkit/oauth_filter'
require 'cloudkit/oauth_store'
require 'cloudkit/openid_filter'
require 'cloudkit/openid_store'
require 'cloudkit/rack/builder'
require 'cloudkit/rack/router'
require 'cloudkit/request'
require 'cloudkit/service'
require 'cloudkit/user_store'

include CloudKit::Constants

module CloudKit
  VERSION = '0.10.0'
end

class Object

  # Execute a method if it exists.
  def try(method) # via defunkt
    send method if respond_to? method
  end
end

class Hash

  # For each key in 'other' that has a non-nil value, merge it into the current
  # Hash.
  def filter_merge!(other={})
    other.each_pair{|k,v| self.merge!(k => v) unless v.nil?}
    self
  end

  # Change the key 'oldkey' to 'newkey'
  def rekey!(oldkey, newkey)
    if self.has_key? oldkey
      self[newkey] = self.delete(oldkey)
    end
  end

  # Return a new Hash, excluding the specified list of keys.
  def excluding(*keys)
    trimmed = self.dup
    keys.each{|k| trimmed.delete(k)}
    trimmed
  end
end

class Array

  # Return a new Array, excluding the specified list of values.
  def excluding(*keys)
    trimmed = self.dup
    trimmed.reject{|v| keys.include?(v)}
  end
end
