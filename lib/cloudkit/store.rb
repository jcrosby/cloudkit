module CloudKit

  # A functional storage interface with HTTP semantics and pluggable adapters.
  class Store
    include ResponseHelpers
    include CloudKit::Util

    # Initialize a new Store, creating its schema if needed. All resources in a
    # Store are automatically versioned.
    #
    # ===Options
    # - :adapter - Optional. A DataMapper Adapter. Defaults to in-memory SQLite.
    # - :collections - Array of resource collections to manage.
    # - :views - Optional. Array of views to be updated based on JSON content.
    #
    # ===Example
    #   store = CloudKit::Store.new(:collections => [:foos, :bars])
    #
    # ===Example
    #   adapter = DataMapper.setup(:default, 'mysql://user:pass@localhost/my_db')
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
    #
    def initialize(options)
      @db          = options[:adapter] || DataMapper.setup(:default, 'sqlite3::memory:')
      @collections = options[:collections]
      @views       = options[:views]
      DataMapper.auto_upgrade!
    end

    # Retrieve a resource or collection of resources based on a URI.
    #
    # ===Parameters
    # - uri - URI of the resource or collection to retrieve.
    # - options - See below.
    #
    # ===Options
    # - :remote_user - Optional. Scopes the dataset if provided.
    # - :limit - Optional. Default is unlimited. Limit the number of records returned by a collection request.
    # - :offset - Optional. Start the list of resources in a collection at offset (0-based).
    # - :any - Optional. Not a literal ":any", but any key or keys defined as extrations from a view.
    #
    # ===URI Types
    #   /cloudkit-meta
    #   /{collection}
    #   /{collection}/_resolved
    #   /{collection}/{uuid}
    #   /{collection}/{uuid}/versions
    #   /{collection}/{uuid}/versions/_resolved
    #   /{collection}/{uuid}/versions/{etag}
    #   /{view}
    #
    # ===Examples
    #   get('/cloudkit-meta')
    #   get('/foos')
    #   get('/foos', :remote_user => 'coltrane')
    #   get('/foos', :limit => 100, :offset => 200)
    #   get('/foos/123')
    #   get('/foos/123/versions')
    #   get('/foos/123/versions/abc')
    #   get('/shiny_foos', :color => 'green')
    #
    # See also: {REST API}[http://getcloudkit.com/rest-api.html]
    #
    def get(uri, options={})
      return invalid_entity_type                        if !valid_collection_type?(collection_type(uri))
      return meta                                       if meta_uri?(uri)
      return resource_collection(uri, options)          if resource_collection_uri?(uri)
      return resolved_resource_collection(uri, options) if resolved_resource_collection_uri?(uri)
      return resource(uri, options)                     if resource_uri?(uri)
      return version_collection(uri, options)           if version_collection_uri?(uri)
      return resolved_version_collection(uri, options)  if resolved_version_collection_uri?(uri)
      return resource_version(uri, options)             if resource_version_uri?(uri)
      return view(uri, options)                         if view_uri?(uri)
      status_404
    end

    # Retrieve the same items as the get method, minus the content/body. Using
    # this method on a single resource URI performs a slight optimization due
    # to the way CloudKit stores its ETags and Last-Modified information on
    # write.
    def head(uri, options={})
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      if resource_uri?(uri) || resource_version_uri?(uri)
        # ETag and Last-Modified are already stored for single items, so a slight
        # optimization can be made for HEAD requests.
        result = CloudKit::Document.first(options.merge(:uri => uri))
        return status_404.head unless result
        return status_410.head if result.deleted?
        return response(200, '', result.etag, result.last_modified)
      else
        get(uri, options).head
      end
    end

    # Update or create a resource at the specified URI. If the resource already
    # exists, an :etag option is required.
    def put(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('PUT')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return data_required       unless options[:json]
      current_resource = resource(uri, options.excluding(:json, :etag, :remote_user))
      return update_resource(uri, options) if current_resource.status == 200
      return current_resource if current_resource.status == 410
      create_resource(uri, options)
    end

    # Create a resource in a given collection.
    def post(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('POST')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return data_required       unless options[:json]
      uri = "#{collection_uri_fragment(uri)}/#{UUID.generate}"
      create_resource(uri, options)
    end

    # Delete the resource specified by the URI. Requires the :etag option.
    def delete(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('DELETE')
      return invalid_entity_type unless @collections.include?(collection_type(uri))
      return etag_required       unless options[:etag]
      original = CloudKit::Document.first(options.excluding(:etag).merge(:uri => uri))
      return status_404 unless (original && (original.remote_user == options[:remote_user]))
      return status_410 if original.deleted?
      return status_412 if original.etag != options[:etag]

      transaction = DataMapper::Transaction.new(CloudKit::Document)
      transaction.begin
      DataMapper.repository(:default).adapter.push_transaction(transaction)

      version_uri = "#{original.uri}/versions/#{original.etag}"
      original.update_attributes(:uri => version_uri)
      gone = CloudKit::Document.create(
        :uri                  => uri,
        :collection_reference => original.collection_reference,
        :resource_reference   => original.resource_reference,
        :remote_user          => original.remote_user,
        :content              => original.content,
        :deleted              => true)
      gone.update_attributes(:etag => nil)

      DataMapper.repository(:default).adapter.pop_transaction
      transaction.commit
      unmap(uri)

      return json_meta_response(200, version_uri, original.etag, original.last_modified)
    end

    # Build a response containing the allowed methods for a given URI.
    def options(uri)
      methods = methods_for_uri(uri)
      allow(methods)
    end

    # Return a list of allowed methods for a given URI.
    def methods_for_uri(uri)
      return meta_methods                         if meta_uri?(uri)
      return resource_collection_methods          if resource_collection_uri?(uri)
      return resolved_resource_collection_methods if resolved_resource_collection_uri?(uri)
      return resource_methods                     if resource_uri?(uri)
      return version_collection_methods           if version_collection_uri?(uri)
      return resolved_version_collection_methods  if resolved_version_collection_uri?(uri)
      return resource_version_methods             if resource_version_uri?(uri)
    end

    # Return the list of methods allowed for the cloudkit-meta URI.
    def meta_methods
      @meta_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    # Return the list of methods allowed for a resource collection.
    def resource_collection_methods
      @resource_collection_methods ||= http_methods.excluding('PUT', 'DELETE')
    end

    # Return the list of methods allowed on a resolved resource collection.
    def resolved_resource_collection_methods
      @resolved_resource_collection_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    # Return the list of methods allowed on an individual resource.
    def resource_methods
      @resource_methods ||= http_methods.excluding('POST')
    end

    # Return the list of methods allowed on a version history collection.
    def version_collection_methods
      @version_collection_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    # Return the list of methods allowed on a resolved version history collection.
    def resolved_version_collection_methods
      @resolved_version_collection_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    # Return the list of methods allowed on a resource version.
    def resource_version_methods
      @resource_version_methods ||= http_methods.excluding('POST', 'PUT', 'DELETE')
    end

    # Return true if this store implements a given HTTP method.
    def implements?(http_method)
      http_methods.include?(http_method.upcase)
    end

    # Return the list of HTTP methods supported by this Store.
    def http_methods
      ['GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'OPTIONS']
    end

    # Return the resource collection URI fragment.
    # Example: collection_uri_fragment('/foos/123') => '/foos
    def collection_uri_fragment(uri)
      "/#{uri_components(uri)[0]}" rescue nil
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

    # Returns true if URI matches /{collection}/_resolved
    def resolved_resource_collection_uri?(uri)
      c = uri_components(uri)
      return c.size == 2 && @collections.include?(c[0].to_sym) && c[1] == '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}
    def resource_uri?(uri)
      c = uri_components(uri)
      return c.size == 2 && @collections.include?(c[0].to_sym) && c[1] != '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions
    def version_collection_uri?(uri)
      c = uri_components(uri)
      return c.size == 3 && @collections.include?(c[0].to_sym) && c[2] == 'versions'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions/_resolved
    def resolved_version_collection_uri?(uri)
      c = uri_components(uri)
      return c.size == 4 && @collections.include?(c[0].to_sym) && c[2] == 'versions' && c[3] == '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions/{etag}
    def resource_version_uri?(uri)
      c = uri_components(uri)
      return c.size == 4 && @collections.include?(c[0].to_sym) && c[2] == 'versions' && c[3] != '_resolved'
    end

    # Returns true if URI matches /{view}
    def view_uri?(uri)
      c = uri_components(uri)
      return c.size == 1 && @views && @views.map{|v| v.name}.include?(c[0].to_sym)
    end

    # Return an array containing the response for each URI in a list.
    def resolve_uris(uris)
      result = []
      uris.each do |uri|
        result << get(uri)
      end
      result
    end

    # Return the version number of this Store.
    def version; 1; end

    protected

    # Return the list of collections managed by this Store.
    def meta
      json = JSON.generate(:uris => @collections.map{|t| "/#{t}"})
      response(200, json, build_etag(json))
    end

    # Return a list of resource URIs for the given collection URI. Sorted by
    # Last-Modified date in descending order.
    def resource_collection(uri, options)
      filter = options.excluding(:offset, :limit).merge(
        :deleted              => false,
        :collection_reference => collection_uri_fragment(uri),
        :conditions           => ['resource_reference = uri'],
        :order                => [:id.desc])
      result = CloudKit::Document.all(filter)
      bundle_collection_result(uri, options, result)
    end

    # Return all documents and their associated metadata for the given
    # collection URI.
    def resolved_resource_collection(uri, options)
      result = CloudKit::Document.all(
        options.excluding(:offset, :limit).merge(
          :deleted              => false,
          :collection_reference => collection_uri_fragment(uri),
          :conditions           => ['resource_reference = uri'],
          :order                => [:id.desc]))
      bundle_resolved_collection_result(uri, options, result)
    end

    # Return the resource for the given URI. Return 404 if not found or if
    # protected and unauthorized, 410 if authorized but deleted.
    def resource(uri, options)
      if resource = CloudKit::Document.first(options.merge!(:uri => uri))
        return status_410 if resource.deleted?
        return response(200, resource.content, resource.etag, resource.last_modified)
      end
      status_404
    end

    # Return a collection of URIs for all versions of a resource including the
    #current version. Sorted by Last-Modified date in descending order.
    def version_collection(uri, options)
      found = CloudKit::Document.first(
        options.excluding(:offset, :limit).merge(
          :uri => current_resource_uri(uri)))
      return status_404 unless found
      result = CloudKit::Document.all(
        options.excluding(:offset, :limit).merge(
          :resource_reference => current_resource_uri(uri),
          :deleted            => false,
          :order              => [:id.desc]))
      bundle_collection_result(uri, options, result)
    end

    # Return all document versions and their associated metadata for a given
    # resource including the current version. Sorted by Last-Modified date in
    # descending order.
    def resolved_version_collection(uri, options)
      found = CloudKit::Document.first(
        options.excluding(:offset, :limit).merge(
          :uri => current_resource_uri(uri)))
      return status_404 unless found#.any?
      result = CloudKit::Document.all(
        options.excluding(:offset, :limit).merge(
          :resource_reference => current_resource_uri(uri),
          :deleted            => false,
          :order              => [:id.desc]))
      bundle_resolved_collection_result(uri, options, result)
    end

    # Return a specific version of a resource.
    def resource_version(uri, options)
      result = CloudKit::Document.first(options.merge(:uri => uri))
      return status_404 unless result
      response(200, result.content, result.etag, result.last_modified)
    end

    # Return a list of URIs for all resources matching the list of key value
    # pairs provided in the options arg.
    def view(uri, options)
      klass = class_for(collection_uri_fragment(uri))
      result = klass.all(options.excluding(:offset, :limit))
      bundle_collection_result(uri, options, result)
    end

    # Create a resource at the specified URI.
    def create_resource(uri, options)
      data = JSON.parse(options[:json]) rescue (return status_422)
      resource = CloudKit::Document.create(
        :uri                  => uri,
        :collection_reference => collection_uri_fragment(uri),
        :resource_reference   => uri,
        :remote_user          => options[:remote_user],
        :content              => options[:json])
      map(uri, data)
      json_meta_response(201, uri, resource.etag, resource.last_modified)
    end

    # Update the resource at the specified URI. Requires the :etag option.
    def update_resource(uri, options)
      data = JSON.parse(options[:json]) rescue (return status_422)
      original = CloudKit::Document.first(
        options.excluding(:json, :etag).merge(:uri => uri))
      return status_404    unless (original && (original.remote_user == options[:remote_user]))
      return etag_required unless options[:etag]
      return status_412    unless options[:etag] == original.etag

      transaction = DataMapper::Transaction.new(CloudKit::Document)
      transaction.begin
      DataMapper.repository(:default).adapter.push_transaction(transaction)

      original.update_attributes(:uri => "#{uri}/versions/#{original.etag}")
      resource = CloudKit::Document.create(
        :uri                  => uri,
        :collection_reference => original.collection_reference,
        :resource_reference   => original.resource_reference,
        :remote_user          => options[:remote_user],
        :content              => options[:json])

      DataMapper.repository(:default).adapter.pop_transaction
      transaction.commit

      map(uri, data)

      return json_meta_response(200, uri, resource.etag, resource.last_modified)
    end

    # Bundle a collection of results as a list of URIs for the response.
    def bundle_collection_result(uri, options, result)
      total  = result.size
      offset = options[:offset].try(:to_i) || 0
      max    = options[:limit] ? offset + options[:limit].to_i : total
      list   = result.to_a[offset...max].map{|r| r.uri}
      json   = uri_list(list, total, offset)
      last_modified = result.first.try(:last_modified) if result.any?
      response(200, json, build_etag(json), last_modified)
    end

    # Bundle a collection of results as a list of documents and the associated
    # metadata (last_modified, uri, etag) that would have accompanied a response
    # to their singular request.
    def bundle_resolved_collection_result(uri, options, result)
      total  = result.size
      offset = options[:offset].try(:to_i) || 0
      max    = options[:limit] ? offset + options[:limit].to_i : total
      list   = result.to_a[offset...max]
      json   = resource_list(list, total, offset)
      last_modified = result.first.last_modified if result.any?
      response(200, json, build_etag(json), last_modified)
    end

    # Generate a JSON URI list.
    def uri_list(list, total, offset)
      JSON.generate(:total => total, :offset => offset, :uris => list)
    end

    # Generate a JSON document list.
    def resource_list(list, total, offset)
      results = []
      list.each do |resource|
        results << {
          :uri           => resource.uri,
          :etag          => resource.etag,
          :last_modified => resource.last_modified,
          :document      => resource.content}
      end
      JSON.generate(:total => total, :offset => offset, :documents => results)
    end

    # Build an ETag for a collection. ETags are generated on write as an
    # optimization for GETs. This method is used for collections of resources
    # where the optimization is not practical.
    def build_etag(data)
      MD5::md5(data.to_s).hexdigest
    end

    # Returns true if the collection type represents a view.
    def is_view?(collection_type)
      @views && @views.map{|v| v.name}.include?(collection_type)
    end

    # Returns true if the collection type is valid for this Store.
    def valid_collection_type?(collection_type)
      @collections.include?(collection_type) ||
        is_view?(collection_type) ||
        collection_type.to_s == 'cloudkit-meta'
    end

    # Delegates the mapping of data from a resource into a view.
    def map(uri, data)
      @views.each{|view| view.map(collection_type(uri), uri, data)} if @views
    end

    # Delegates removal of view data.
    def unmap(uri)
      @views.each{|view| view.unmap(collection_type(uri), uri)} if @views
    end

    # Return a HTTP date representing 'now.'
    def timestamp
      Time.now.httpdate
    end

    # Return the adapter instance used by this Store.
    def db; @db; end
  end
end
