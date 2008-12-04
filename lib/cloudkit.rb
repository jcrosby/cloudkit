require 'rubygems'
require 'erb'
require 'json'
require 'md5'
require 'openid'
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
require 'cloudkit/util'
require 'cloudkit/store/adapter'
require 'cloudkit/store/extraction_view'
require 'cloudkit/store/get_helpers'
require 'cloudkit/store/response'
require 'cloudkit/store/response_helpers'
require 'cloudkit/store/sql_adapter'
require 'cloudkit/store/validators'
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

class Object
  def try(method) # via defunkt
    send method if respond_to? method
  end
end

class Hash
  def filter_merge!(other={})
    other.each_pair{|k,v| self.merge!(k => v) if v}
    self
  end

  def rekey!(oldkey, newkey)
    if self[oldkey]
      self[newkey] = self.delete(oldkey)
    end
  end
end
