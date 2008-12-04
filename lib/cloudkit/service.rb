# TODO explain versioning in this class's rdocs
# TODO one block to explain status codes. one block for headers.
module CloudKit
  
  # A CloudKit Service is Rack Middleware implementing an HTTP 1.1 interface for
  # one or more resource collections.
  #
  # ==Examples
  #
  # A basic service in a rackup file exposing _items_ and _things_
  #   require 'cloudkit'
  #   use CloudKit::Service, :collections => [:items, :things]
  #   run lambda{|env| [200, {}, ['Hello']]}
  #
  # Again, an _items_ and _things_ service, this time with OpenID and OAuth
  #   require 'cloudkit'
  #   use Rack::Session::Pool
  #   use CloudKit::OAuthFilter
  #   use CloudKit::OpenIDFilter
  #   use CloudKit::Service, :collections => [:items, :things]
  #   run lambda{|env| [200, {}, ['Hello']]}
  #
  # Exactly like the previous example, using the Rack::Builder shortcut
  #   require 'cloudkit'
  #   expose :items, :things
  #   run lambda{|env| [200, {}, ['Hello']]}
  #
  # The same as above, using a default developer index page instead of a page
  # containing 'Hello'
  #   require 'cloudkit'
  #   expose :items, :things
  #
  # ==HTTP Interface
  #
  # Request:
  #   GET /items
  #
  # Return a collection of all _items_. Checks for the existence of an upstream
  # auth proxy (such as OpenIDFilter or OAuthFilter) and filters the set of
  # items based on this information. The status code is always 200 for public
  # services or authenticated users. 302s and 401s are served upstream when
  # appropriate and are documented as part of those middleware components.
  #
  # Empty response:
  #   HTTP 1.1 200 OK
  #   
  #   {"documents":[]}
  #
  # Response with data:
  #   HTTP 1.1 200 OK
  #   
  #   {"documents":[
  #     {"id":"abc","etag":"123def456","last_modified":"ZZZZZZZZZZZZZ","name":"chair"},
  #     {"id":"xyz","etag":"789ghi012","last_modified":"ZZZZZZZZZZZZZ","name":"table"}
  #   ]}
  #
  # GET /items/xyz
  #
  # Return a specific resource. Checks for the existence of an upstream auth
  # proxy and adjusts the response based on this information. Authenticated
  # unauthorized users receive 404s when auth is required. Unauthenticated users
  # received 302s and 401s upstream.
  #
  # Headers:
  # - If-Match: Optional
  #
  # Response:
  #
  # ====POST
  # *Response*
  #
  # Headers:
  #
  # ====PUT
  # *Request*
  #
  # Headers:
  # - If-Match: Conditionally required.
  #
  # *Response*
  #
  # Headers:
  #
  # ====DELETE
  # *Request*
  #
  # Headers:
  # - If-Match: Required
  #
  # *Response*
  #
  # Headers:
  #
  # ====HEAD
  #
  # ====OPTIONS
  #
  class Service
    include Util
    @@lock = Mutex.new
    def initialize(app, options)
      @app   = app
      @types = options[:collections]
    end

    def call(env)
      @@lock.synchronize do
        @store = Store.new(
          :adapter     => SQLAdapter.new(env[storage_uri_key]),
          :collections => @types)
      end unless @store
      @request = Request.new(env)
      @type = @types.detect{|type| @request.path_info.match("/#{type.to_s}")}
      if !@type
        @app.call(env)
      else
        return configuration_error if (@request.using_auth? && auth_missing?)
        send(@request.request_method.downcase) rescue unknown_method
      end
    end

    protected

    def get
      if @request.history_path?
        response = @store.get(Store.history(@type), identify)
      elsif @request.etags_path?
        response = @store.etags(@type, identify)
      elsif @request.meta_path?
        response = @store.meta(@type, identify)
      else
        response = @store.get(@type, identify)
        if @request.doc_id
          base_url = "#{@request.scheme}://#{@request.env['HTTP_HOST']}/#{@type}/#{@request.doc_id}"
          base_rel_url = "http://joncrosby.me/cloudkit/1.0/rel"
          response['Link'] = "<#{base_url}/history>; rel=\"#{base_rel_url}/history\", " +
            "<#{base_url}/etags>; rel=\"#{base_rel_url}/etags\""
        end
      end
      response.to_rack
    end

    def post
      if tunnel_methods.include?(@request['_method'].try(:upcase))
        return send(@request['_method'].downcase)
      end 
      @store.post(@type, identify(:data => @request.body.string)).to_rack
    end

    def put
      @store.put(@type, identify(:data => @request.body.string)).to_rack
    end

    def delete
      @store.delete(@type, identify).to_rack
    end

    # Until a head method is added to the store, this method merely offers a
    # bandwidth optimization and updated staleness information for associated
    # caching proxies.
    def head
      response = get
      [response[0], response[1], []]
    end

    def options
      [200, allow_header, []]
    end

    def trace
      [405, allow_header, []]
    end

    def unknown_method
      [501, {}, []]
    end

    def identify(options={})
      options.filter_merge!(
        :id            => @request.doc_id,
        :remote_user   => @request.current_user,
        :if_match      => @request.if_match,
        :if_none_match => @request.if_none_match)
    end

    def allow_header
      {'Allow' => 'GET, POST, PUT, DELETE, OPTIONS'}
    end

    def auth_missing?
      @request.current_user == nil
    end

    def configuration_error
      [500, {'Content-Type' => 'text/html'}, ['server misconfigured']]
    end

    def tunnel_methods
      ['PUT', 'DELETE', 'OPTIONS', 'HEAD', 'TRACE']
    end
  end
end
