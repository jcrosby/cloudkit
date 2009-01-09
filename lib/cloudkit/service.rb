module CloudKit

  # A CloudKit Service is Rack middleware providing a REST/HTTP 1.1 interface to
  # a Store. Its primary purpose is initialize and adapt a Store for use in a
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

    def initialize(app, options)
      @app         = app
      @collections = options[:collections]
    end

    def call(env)
      @@lock.synchronize do
        @store = Store.new(
          :adapter     => SQLAdapter.new(env[CLOUDKIT_STORAGE_URI]),
          :collections => @collections)
      end unless @store

      request = Request.new(env)
      unless bypass?(request)
        return auth_config_error if (request.using_auth? && auth_missing?(request))
        return not_implemented unless @store.implements?(request.request_method)
        send(request.request_method.downcase, request) rescue internal_server_error
      else
        @app.call(env)
      end
    end

    protected

    def get(request)
      response = @store.get(
        request.path_info,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :offset      => request['offset'],
          :limit       => request['limit']))
      inject_link_headers(request, response)
      response.to_rack
    end

    def post(request)
      if tunnel_methods.include?(request['_method'].try(:upcase))
        return send(request['_method'].downcase)
      end
      @store.post(
        request.path_info,
        {:json => request.json}.filter_merge!(
          :remote_user => request.current_user)).to_rack
    end

    def put(request)
      @store.put(
        request.path_info,
        {:json => request.json}.filter_merge!(
          :remote_user => request.current_user,
          :etag        => request.if_match)).to_rack
    end

    def delete(request)
      @store.delete(
        request.path_info,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :etag        => request.if_match)).to_rack
    end

    def head(request)
      response = @store.head(
        request.path_info,
        {}.filter_merge!(
          :remote_user => request.current_user,
          :offset      => request['offset'],
          :limit       => request['limit']))
      inject_link_headers(request, response)
      response.to_rack
    end

    def options(request)
      @store.options(request.path_info).to_rack
    end

    def inject_link_headers(request, response)
      response['Link'] = versions_link_header(request) if @store.resource_uri?(request.path_info)
      response['Link'] = resolved_link_header(request) if @store.resource_collection_uri?(request.path_info)
      response['Link'] = index_link_header(request)    if @store.resolved_resource_collection_uri?(request.path_info)
      response['Link'] = resolved_link_header(request) if @store.version_collection_uri?(request.path_info)
      response['Link'] = index_link_header(request)    if @store.resolved_version_collection_uri?(request.path_info)
    end

    def versions_link_header(request)
      base_url = "#{request.scheme}://#{request.env['HTTP_HOST']}#{request.path_info}"
      "<#{base_url}/versions>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/versions\""
    end

    def resolved_link_header(request)
      base_url = "#{request.scheme}://#{request.env['HTTP_HOST']}#{request.path_info}"
      "<#{base_url}/_resolved>; rel=\"http://joncrosby.me/cloudkit/1.0/rel/resolved\""
    end

    def index_link_header(request)
      index_path = request.path_info.sub(/\/_resolved(\/)*$/, '')
      base_url = "#{request.scheme}://#{request.env['HTTP_HOST']}#{index_path}"
      "<#{base_url}>; rel=\"index\""
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
      !collection && !@store.meta_uri?(request.path_info)
    end
  end
end
