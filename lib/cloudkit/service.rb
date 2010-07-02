module CloudKit

  # A CloudKit Service is Rack middleware providing a REST/HTTP 1.1 interface to
  # a Store. Its primary purpose is to initialize and adapt a Store for use in a
  # Rack middleware stack.
  #
  # ==Examples
  #
  # A rackup file exposing _items_ and _things_ as REST collections:
  #   require 'cloudkit'
  #   expose :items, :things
  #
  # The same as above, adding OpenID and OAuth/Discovery:
  #   require 'cloudkit'
  #   contain :items, :things
  #
  # An explicit setup, without using the Rack::Builder shortcuts:
  #   require 'cloudkit'
  #   use Rack::Session::Pool
  #   use CloudKit::OAuthFilter
  #   use CloudKit::OpenIDFilter
  #   use CloudKit::Service, :collections => [:items, :things]
  #   run lambda{|env| [200, {'Content-Type' => 'text/html'}, ['Hello']]}
  #
  # For more examples, including the use of different storage implementations,
  # see the Table of Contents in the examples directory.
  class Service
    include ResponseHelpers

    @@lock = Mutex.new

    attr_reader :store

    def initialize(app, options)
      @app         = app
      @collections = options[:collections]
    end

    def call(env)
      @@lock.synchronize do
        @store = Store.new(:collections => @collections)
      end unless @store

      request = Request.new(env)
      unless bypass?(request)
        return auth_config_error if (request.using_auth? && auth_missing?(request))
        return not_implemented unless @store.implements?(request.request_method)
        send(request.request_method.downcase, request) #rescue internal_server_error.to_rack
      else
        @app.call(env)
      end
    end

    protected

    def get(request)
      response = @store.get(
        request.uri,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :offset      => request['offset'],
          :limit       => request['limit'],
          :search      => request['search']))
      inject_link_headers(request, response)
      response.to_rack
    end

    def post(request)
      if tunnel_methods.include?(request['_method'].try(:upcase))
        return send(request['_method'].downcase, request)
      end
      response = @store.post(
        request.uri,
        {:json => request.json}.filter_merge!(
          :remote_user => request.current_user))
      update_location_header(request, response)
      response.to_rack
    end

    def put(request)
      response = @store.put(
        request.uri,
        {:json => request.json}.filter_merge!(
          :remote_user => request.current_user,
          :etag        => request.if_match))
      update_location_header(request, response)
      response.to_rack
    end

    def delete(request)
      @store.delete(
        request.uri,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :etag        => request.if_match)).to_rack
    end

    def head(request)
      response = @store.head(
        request.uri,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :offset      => request['offset'],
          :limit       => request['limit']))
      inject_link_headers(request, response)
      response.to_rack
    end

    def options(request)
      @store.options(request.uri).to_rack
    end

    def inject_link_headers(request, response)
      response['Link'] = versions_link_header(request) if request.uri.resource_uri?
      response['Link'] = resolved_link_header(request) if request.uri.resource_collection_uri?
      response['Link'] = index_link_header(request)    if request.uri.resolved_resource_collection_uri?
      response['Link'] = resolved_link_header(request) if request.uri.version_collection_uri?
      response['Link'] = index_link_header(request)    if request.uri.resolved_version_collection_uri?
    end

    def versions_link_header(request)
      base_url = "#{request.domain_root}#{request.path_info}"
      "<#{base_url}/versions>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/versions\""
    end

    def resolved_link_header(request)
      base_url = "#{request.domain_root}#{request.path_info}"
      "<#{base_url}/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\""
    end

    def index_link_header(request)
      index_path = request.path_info.sub(/\/_resolved(\/)*$/, '')
      base_url = "#{request.domain_root}#{index_path}"
      "<#{base_url}>; rel=\"index\""
    end

    def update_location_header(request, response)
      return unless response['Location']
      response['Location'] = "#{request.domain_root}#{response['Location']}"
    end

    def auth_missing?(request)
      request.current_user == nil
    end

    def tunnel_methods
      ['PUT', 'DELETE', 'OPTIONS', 'HEAD', 'TRACE']
    end

    def not_implemented
      json_error_response(501, 'not implemented').to_rack
    end

    def auth_config_error
      json_error_response(500, 'server auth misconfigured').to_rack
    end

    def bypass?(request)
      collection = @collections.detect{|type| request.path_info.match("/#{type.to_s}")}
      !collection && !request.uri.meta_uri?
    end
  end
end
