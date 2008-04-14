require 'oauth/request_proxy/base'
require 'uri'
module OAuth::RequestProxy
  class RackRequest < OAuth::RequestProxy::Base
    proxies Rack::Request
    
    def method
      request.request_method
    end
    
    def uri
      uri = URI.parse(request.url)
      uri.query = nil
      uri.to_s
    end

    def parameters
      if options[:clobber_request]
        options[:parameters] || {}
      else
        params = request_params.merge(query_params).merge(header_params)
        params.merge(options[:parameters] || {})
      end
    end
    
    def signature
      parameters['oauth_signature']
    end
    
    protected

    def header_params
      %w( X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION ).each do |header|
        next unless request.env.include?(header)

        header = request.env[header]
        next unless header[0,6] == 'OAuth '

        oauth_param_string = header[6,header.length].split(/[,=]/)
        oauth_param_string.map! { |v| unescape(v.strip) }
        oauth_param_string.map! { |v| v =~ /^\".*\"$/ ? v[1..-2] : v }
        oauth_params = Hash[*oauth_param_string.flatten]
        oauth_params.reject! { |k,v| k !~ /^oauth_/ }

        return oauth_params
      end

      return {}
    end

    def query_params
      request.GET
    end

    def request_params
      request.params
    end

    def unescape(value)
      URI.unescape(value.gsub('+', '%2B'))
    end
  end
end