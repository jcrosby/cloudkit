module CloudKit
  # A functional storage interface with HTTP semantics and pluggable adapters.
  class Store
    include CloudKit::Util
    include ResponseHelpers

    # Initialize a new Store, creating its schema if needed. All resources in a
    # Store are automatically versioned.
    #
    # Options:
    # :adapter - Optional. An instance of Adapter. Defaults to in-memory SQLite.
    # :collections - Array of resource collections to manage.
    # :views - Optional. Array of views to be updated based on JSON content.
    #
    # Example:
    #   store = CloudKit::Store.new(:collections => [:foos, :bars])
    #
    # Example:
    #   adapter = CloudKit::SQLAdapter.new('mysql://user:pass@localhost/my_db')
    #   fruit_color_view = CloudKit::ExtractionView.new(
    #     :fruits_by_color_and_season,
    #     :observe => :fruits,
    #     :extract => [:color, :season])
    #   store = CloudKit::Store.new(
    #     :adapter     => adapter,
    #     :collections => [:foos, :fruits],
    #     :views       => [fruit_color_view])
    #
    # See also: Adapter, ExtractionView, Response
    def initialize(options)
      @db          = options[:adapter] || SQLAdapter.new
      @collections = options[:collections]
      @views       = options[:views]
      @views.each {|view| view.initialize_storage(@db)} if @views
    end

    # Retrieve a resource or collection of resources based on a URI.
    #
    # Parameters:
    # uri - URI of the resource or collection to retrieve.
    # options - See below.
    #
    # Options:
    # :remote_user - Optional. Scopes the dataset if provided.
    # :limit - Optional. Default is unlimited. Limit the number of records returned by a collection request.
    # :offset - Optional. Start the list of resources in a collection at offset (0-based).
    # :any - Optional. Not a literal ":any", but any key or keys defined as extrations from a view.
    #
    # URI Types:
    # /cloudkit-meta
    # /{collection}
    # /{collection}/{uuid}
    # /{collection}/{uuid}/versions
    # /{collection}/{uuid}/versions/{etag}
    # /{view}
    #
    # Examples:
    # get('/cloudkit-meta')
    # get('/foos')
    # get('/foos', :remote_user => 'coltrane')
    # get('/foos', :limit => 100, :offset => 200)
    # get('/foos/123')
    # get('/foos/123/versions')
    # get('/foos/123/versions/abc')
    # get('/shiny_foos', :color => 'green')
    #
    # See also: REST API
    def get(uri, options={})
      return invalid_entity_type               if !valid_collection_type?(collection_type(uri))
      return meta                              if meta_uri?(uri)
      return resource_collection(uri, options) if resource_collection_uri?(uri)
      return resource(uri, options)            if resource_uri?(uri)
      return version_collection(uri, options)  if version_collection_uri?(uri)
      return resource_version(uri, options)    if resource_version_uri?(uri)
      return view(uri, options)                if view_uri?(uri)
      status_404
    end

    def head(uri, options={})
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      if resource_uri?(uri) || resource_version_uri?(uri)
        # ETag and Last-Modified are already stored for single items, so a slight
        # optimization can be made for HEAD requests.
        result = @db[store_key].
          select(:etag, :last_modified, :deleted).
          filter(options.merge(:uri => uri))
        if result.any?
          result = result.first
          return status_410.head if result[:deleted]
          return response(200, '', result[:etag], result[:last_modified])
        end
        status_404.head
      else
        get(uri, options).head
      end
    end

    def put(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('PUT')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return data_required       unless options[:json]
      current_resource = resource(uri, options.excluding(:json, :etag, :remote_user))
      return update_resource(uri, options) if current_resource.status == 200
      create_resource(uri, options)
    end

    def post(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('POST')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return data_required       unless options[:json]
      uri = "#{collection_uri_fragment(uri)}/#{UUID.generate}"
      create_resource(uri, options)
    end

    def delete(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('DELETE')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return etag_required       unless options[:etag]
      original = @db[store_key].
        filter(options.excluding(:etag).merge(:uri => uri))
      if original.any?
        item = original.first
        return status_404 unless item[:remote_user] == options[:remote_user]
        return status_410 if item[:deleted]
        return status_412 if item[:etag] != options[:etag]
        version_uri = ''
        @db.transaction do
          version_uri = "#{item[:uri]}/versions/#{item[:etag]}"
          original.update(:uri => version_uri)
          @db[store_key].insert(
            :uri                  => item[:uri],
            :collection_reference => item[:collection_reference],
            :resource_reference   => item[:resource_reference],
            :remote_user          => item[:remote_user],
            :content              => item[:content],
            :deleted              => true)
          # TODO unmap
        end
        return json_meta_response(200, version_uri, item[:etag], item[:last_modified])
      end
      status_404
    end

    def options(uri)
      methods = methods_for_uri(uri)
      allow(methods)
    end

    def methods_for_uri(uri)
      if meta_uri?(uri)
        meta_methods
      elsif resource_collection_uri?(uri)
        resource_collection_methods
      elsif resource_uri?(uri)
        resource_methods
      elsif version_collection_uri?(uri)
        version_collection_methods
      elsif resource_version_uri?(uri)
        resource_version_methods
      end
    end

    def meta_methods
      @meta_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    def resource_collection_methods
      @resource_collection_methods ||= http_methods.excluding('PUT', 'DELETE')
    end

    def resource_methods
      @resource_methods ||= http_methods.excluding('POST')
    end

    def version_collection_methods
      @version_collection_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    def resource_version_methods
      @resource_version_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    def implements?(http_method)
      http_methods.include?(http_method.upcase)
    end

    def http_methods
      ['GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'OPTIONS']
    end

    # Return the resource collection URI fragment.
    # Example: collection_uri_fragment('/foos/123') => '/foos
    def collection_uri_fragment(uri)
      uri_components(uri)[0] rescue nil
    end

    # Return the resource collection referenced by a URI.
    # Example: collection_type('/foos/123') => :foos
    def collection_type(uri)
      uri_components(uri)[0].to_sym rescue nil
    end

    # Return the URI for the current version of a resource.
    # Example: current_resource_uri('/foos/123/versions/abc') => '/foos/123'
    def current_resource_uri(uri)
      "/#{uri_components(uri)[0..1].join('/')}" rescue nil
    end

    # Splits a URI into its components
    def uri_components(uri)
      uri.split('/').reject{|x| x == '' || x == nil} rescue []
    end

    # Returns true if URI matches /cloudkit-meta
    def meta_uri?(uri)
      c = uri_components(uri)
      return c.size == 1 && c[0] == 'cloudkit-meta'
    end

    # Returns true if URI matches /{collection}
    def resource_collection_uri?(uri)
      c = uri_components(uri)
      return c.size == 1 && @collections.include?(c[0].to_sym)
    end

    # Returns true if URI matches /{collection}/{uuid}
    def resource_uri?(uri)
      c = uri_components(uri)
      return c.size == 2 && @collections.include?(c[0].to_sym)
    end

    # Returns true if URI matches /{collection}/{uuid}/versions
    def version_collection_uri?(uri)
      c = uri_components(uri)
      return c.size == 3 && @collections.include?(c[0].to_sym) && c[2] == 'versions'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions/{etag}
    def resource_version_uri?(uri)
      c = uri_components(uri)
      return c.size == 4 && @collections.include?(c[0].to_sym) && c[2] == 'versions'
    end

    # Returns true if URI matches /{view}
    def view_uri?(uri)
      c = uri_components(uri)
      return c.size == 1 && @views && @views.map{|v| v.name}.include?(c[0].to_sym)
    end

    def resolve_uris(uris)
      result = []
      uris.each do |uri|
        result << get(uri)
      end
      result
    end

    def reset!
      @db.schema.keys.each do |table|
        @db[table].delete
      end
    end

    def version; 1; end

    protected

    def meta
      json = JSON.generate(:uris => @collections.map{|t| "/#{t}"})
      response(200, json, build_etag(json))
    end

    def resource_collection(uri, options)
      result = @db[store_key].
        select(:uri, :last_modified).
        filter(options.excluding(:offset, :limit).merge(:deleted => false)).
        filter(:collection_reference => collection_uri_fragment(uri)).
        filter('resource_reference = uri').
        reverse_order(:id)
      bundle_collection_result(uri, options, result)
    end

    def resource(uri, options)
      result = @db[store_key].
        select(:content, :etag, :last_modified, :deleted).
        filter(options.merge!(:uri => uri))
      if result.any?
        result = result.first
        return status_410 if result[:deleted]
        return response(200, result[:content], result[:etag], result[:last_modified])
      end
      status_404
    end

    def version_collection(uri, options)
      found = @db[store_key].
        select(:uri).
        filter(options.excluding(:offset, :limit).merge(
          :uri => current_resource_uri(uri)))
      return status_404 unless found.any?
      result = @db[store_key].
        select(:uri, :last_modified).
        filter(:resource_reference => current_resource_uri(uri)).
        filter(options.excluding(:offset, :limit).merge(:deleted => false)).
        reverse_order(:id)
      bundle_collection_result(uri, options, result)
    end

    def resource_version(uri, options)
      result = @db[store_key].
        select(:content, :etag, :last_modified).
        filter(options.merge(:uri => uri))
      return status_404 unless result.any?
      result = result.first
      response(200, result[:content], result[:etag], result[:last_modified])
    end

    def view(uri, options)
      result = @db[collection_type(uri)].
        select(:uri).
        filter(options.excluding(:offset, :limit))
      bundle_collection_result(uri, options, result)
    end

    def create_resource(uri, options)
      data = JSON.parse(options[:json]) rescue (return status_422)
      etag = UUID.generate
      last_modified = timestamp
      @db[store_key].insert(
        :uri                  => uri,
        :collection_reference => collection_uri_fragment(uri),
        :resource_reference   => uri,
        :etag                 => etag,
        :last_modified        => last_modified,
        :remote_user          => options[:remote_user],
        :content              => options[:json])
      map(uri, data)
      json_meta_response(201, uri, etag, last_modified)
    end

    def update_resource(uri, options)
      data = JSON.parse(options[:json]) rescue (return status_422)
      original = @db[store_key].
        filter(options.excluding(:json, :etag).merge(:uri => uri))
      if original.any?
        item = original.first
        return status_404    unless item[:remote_user] == options[:remote_user]
        return etag_required unless options[:etag]
        return status_412    unless options[:etag] == item[:etag]
        etag = UUID.generate
        last_modified = timestamp
        @db.transaction do
          original.update(:uri => "#{uri}/versions/#{item[:etag]}")
          @db[store_key].insert(
            :uri                  => uri,
            :collection_reference => item[:collection_reference],
            :resource_reference   => item[:resource_reference],
            :etag                 => etag,
            :last_modified        => last_modified,
            :remote_user          => options[:remote_user],
            :content              => options[:json])
        end
        map(uri, data)
        return json_meta_response(200, uri, etag, last_modified)
      end
      status_404
    end

    def bundle_collection_result(uri, options, result)
      total  = result.count
      offset = options[:offset].try(:to_i) || 0
      max    = options[:limit] ? offset + options[:limit].to_i : total
      list   = result.all[offset...max].map{|r| r[:uri]}
      json   = uri_list(list, total, offset)
      last_modified = result.first[:last_modified] if result.any?
      response(200, json, build_etag(json), last_modified)
    end

    def uri_list(list, total, offset)
      JSON.generate(:total => total, :offset => offset, :uris => list)
    end

    def build_etag(data)
      MD5::md5(data.to_s).hexdigest
    end

    def is_view?(collection_type)
      @views && @views.map{|v| v.name}.include?(collection_type)
    end

    def valid_collection_type?(collection_type)
      @collections.include?(collection_type) ||
        is_view?(collection_type) ||
        collection_type.to_s == 'cloudkit-meta'
    end

    def map(uri, data)
      @views.each{|view| view.map(@db, collection_type(uri), uri, data)} if @views
    end

    def unmap(type, id)
      @views.each{|view| view.unmap(@db, type, id)} if @views
    end

    def timestamp
      Time.now.httpdate
    end

    def db; @db; end
  end
end
