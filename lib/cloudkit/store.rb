module CloudKit

  # A functional storage interface with HTTP semantics and pluggable adapters.
  class Store
    include ResponseHelpers
    include CloudKit::Util

    # Initialize a new Store. All resources in a Store are automatically
    # versioned.
    #
    # ===Options
    # - :collections - Array of resource collections to manage.
    #
    # ===Example
    #   store = CloudKit::Store.new(:collections => [:foos, :bars])
    #
    # See also: Response
    #
    def initialize(options)
      CloudKit.setup_storage_adapter unless CloudKit.storage_adapter
      @collections = options[:collections]
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
    # - :any - Optional. Not a literal ":any", but any key or keys that are top level JSON keys. This is a starting point for future JSONPath/JSONQuery support.
    #
    # ===URI Types
    #   /cloudkit-meta
    #   /{collection}
    #   /{collection}/_resolved
    #   /{collection}/{uuid}
    #   /{collection}/{uuid}/versions
    #   /{collection}/{uuid}/versions/_resolved
    #   /{collection}/{uuid}/versions/{etag}
    #
    # ===Examples
    #   get('/cloudkit-meta')
    #   get('/foos')
    #   get('/foos', :remote_user => 'coltrane')
    #   get('/foos', :limit => 100, :offset => 200)
    #   get('/foos/123')
    #   get('/foos/123/versions')
    #   get('/foos/123/versions/abc')
    #
    # See also: {REST API}[http://getcloudkit.com/rest-api.html]
    #
    def get(uri, options={})
      return invalid_entity_type                        if !valid_collection_type?(uri.collection_type)
      return meta                                       if uri.meta_uri?
      return resource_collection(uri, options)          if uri.resource_collection_uri?
      return resolved_resource_collection(uri, options) if uri.resolved_resource_collection_uri?
      return resource(uri, options)                     if uri.resource_uri?
      return version_collection(uri, options)           if uri.version_collection_uri?
      return resolved_version_collection(uri, options)  if uri.resolved_version_collection_uri?
      return resource_version(uri, options)             if uri.resource_version_uri?
      status_404
    end

    # Retrieve the same items as the get method, minus the content/body. Using
    # this method on a single resource URI performs a slight optimization due
    # to the way CloudKit stores its ETags and Last-Modified information on
    # write.
    def head(uri, options={})
      return invalid_entity_type unless @collections.include?(uri.collection_type)
      if uri.resource_uri? || uri.resource_version_uri?
        # ETag and Last-Modified are already stored for single items, so a slight
        # optimization can be made for HEAD requests.
        result = CloudKit::Resource.first(options.merge(:uri => uri.string))
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
      return invalid_entity_type unless @collections.include?(uri.collection_type)
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
      return invalid_entity_type unless @collections.include?(uri.collection_type)
      return data_required       unless options[:json]
      create_resource(uri, options)
    end

    # Delete the resource specified by the URI. Requires the :etag option.
    def delete(uri, options={})
      methods = methods_for_uri(uri)
      return status_405(methods) unless methods.include?('DELETE')
      return invalid_entity_type unless @collections.include?(uri.collection_type)
      return etag_required       unless options[:etag]
      resource = CloudKit::Resource.first(options.excluding(:etag).merge(:uri => uri.string))
      return status_404 unless (resource && (resource.remote_user == options[:remote_user]))
      return status_410 if resource.deleted?
      return status_412 if resource.etag != options[:etag]

      resource.delete
      archived_resource = resource.previous_version
      return json_meta_response(archived_resource.uri.string, archived_resource.etag, resource.last_modified)
    end

    # Build a response containing the allowed methods for a given URI.
    def options(uri)
      methods = methods_for_uri(uri)
      allow(methods)
    end

    # Return a list of allowed methods for a given URI.
    def methods_for_uri(uri)
      return meta_methods                         if uri.meta_uri?
      return resource_collection_methods          if uri.resource_collection_uri?
      return resolved_resource_collection_methods if uri.resolved_resource_collection_uri?
      return resource_methods                     if uri.resource_uri?
      return version_collection_methods           if uri.version_collection_uri?
      return resolved_version_collection_methods  if uri.resolved_version_collection_uri?
      return resource_version_methods             if uri.resource_version_uri?
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

    # Return an array containing the response for each URI in a list.
    def resolve_uris(uris) # TODO - remove if no longer needed
      result = []
      uris.each do |uri|
        result << get(uri)
      end
      result
    end
    
    def storage_adapter
      CloudKit.storage_adapter
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
        :collection_reference => uri.collection_uri_fragment,
        :archived             => false)
      result = CloudKit::Resource.current(filter)
      bundle_collection_result(uri.string, options, result)
    end

    # Return all documents and their associated metadata for the given
    # collection URI.
    def resolved_resource_collection(uri, options)
      result = CloudKit::Resource.current(
        options.excluding(:offset, :limit).merge(
          :collection_reference => uri.collection_uri_fragment))
      bundle_resolved_collection_result(uri, options, result)
    end

    # Return the resource for the given URI. Return 404 if not found or if
    # protected and unauthorized, 410 if authorized but deleted.
    def resource(uri, options)
      if resource = CloudKit::Resource.first(options.merge!(:uri => uri.string))
        return status_410 if resource.deleted?
        return response(200, resource.json, resource.etag, resource.last_modified)
      end
      status_404
    end

    # Return a collection of URIs for all versions of a resource including the
    # current version. Sorted by Last-Modified date in descending order.
    def version_collection(uri, options)
      found = CloudKit::Resource.first(
        options.excluding(:offset, :limit).merge(
          :uri => uri.current_resource_uri))
      return status_404 unless found
      result = CloudKit::Resource.all( # TODO - just use found.versions
        options.excluding(:offset, :limit).merge(
          :resource_reference => uri.current_resource_uri,
          :deleted            => false))
      bundle_collection_result(uri.string, options, result)
    end

    # Return all document versions and their associated metadata for a given
    # resource including the current version. Sorted by Last-Modified date in
    # descending order.
    def resolved_version_collection(uri, options)
      found = CloudKit::Resource.first(
        options.excluding(:offset, :limit).merge(
          :uri => uri.current_resource_uri))
      return status_404 unless found
      result = CloudKit::Resource.all(
        options.excluding(:offset, :limit).merge(
          :resource_reference => uri.current_resource_uri,
          :deleted            => false))
      bundle_resolved_collection_result(uri, options, result)
    end

    # Return a specific version of a resource.
    def resource_version(uri, options)
      result = CloudKit::Resource.first(options.merge(:uri => uri.string))
      return status_404 unless result
      response(200, result.json, result.etag, result.last_modified)
    end

    # Create a resource at the specified URI.
    def create_resource(uri, options)
      JSON.parse(options[:json]) rescue (return status_422)
      resource = CloudKit::Resource.create(uri, options[:json], options[:remote_user])
      json_create_response(resource.uri.string, resource.etag, resource.last_modified)
    end

    # Update the resource at the specified URI. Requires the :etag option.
    def update_resource(uri, options)
      JSON.parse(options[:json]) rescue (return status_422)
      resource = CloudKit::Resource.first(
        options.excluding(:json, :etag).merge(:uri => uri.string))
      return status_404    unless (resource && (resource.remote_user == options[:remote_user]))
      return etag_required unless options[:etag]
      return status_412    unless options[:etag] == resource.etag
      resource.update(options[:json])
      return json_meta_response(uri.string, resource.etag, resource.last_modified)
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
      JSON.generate(:total => total, :offset => offset, :uris => list.map { |u| u.string })
    end

    # Generate a JSON document list.
    def resource_list(list, total, offset)
      results = []
      list.each do |resource|
        results << {
          :uri           => resource.uri.string,
          :etag          => resource.etag,
          :last_modified => resource.last_modified,
          :document      => resource.json}
      end
      JSON.generate(:total => total, :offset => offset, :documents => results)
    end

    # Build an ETag for a collection. ETags are generated on write as an
    # optimization for GETs. This method is used for collections of resources
    # where the optimization is not practical.
    def build_etag(data)
      Digest::MD5.hexdigest(data.to_s)
    end

    # Returns true if the collection type is valid for this Store.
    def valid_collection_type?(collection_type)
      @collections.include?(collection_type) || collection_type.to_s == 'cloudkit-meta'
    end
  end
end
