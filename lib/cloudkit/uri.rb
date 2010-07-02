require 'uri'
module CloudKit

  # A CloudKit::URI wraps a URI string, adding methods useful for routing
  # in CloudKit as well as caching URI components for future comparisons.
  class URI

    # The string form of a URI.
    attr_reader :string

    # Create a new URI with the given string.
    def initialize(string, escape = true)
      @string = escape ? ::URI.escape(::URI.unescape(string)) : string
    end

    # Return the resource collection URI fragment.
    #   Example: URI.new('/foos/123').collection_uri_fragment => '/foos
    def collection_uri_fragment
      "/#{components[0]}" rescue nil
    end

    # Splits a URI into its components
    def components
      @components ||= @string.split('/').reject{|x| x == '' || x == nil} rescue []
    end

    # Return the resource collection referenced by a URI.
    #   Example: URI.new('/foos/123').collection_type => :foos
    def collection_type
      components[0].to_sym rescue nil
    end

    # Return the URI for the current version of a resource.
    #   Example: URI.new('/foos/123/versions/abc').current_resource_uri => '/foos/123'
    def current_resource_uri
      "/#{components[0..1].join('/')}" rescue nil
    end

    # Returns true if URI matches /cloudkit-meta
    def meta_uri?
      return components.size == 1 && components[0] == 'cloudkit-meta'
    end

    # Returns true if URI matches /{collection}
    def resource_collection_uri?
      return components.size == 1 && components[0] != 'cloudkit-meta'
    end

    # Returns true if URI matches /{collection}/_resolved
    def resolved_resource_collection_uri?
      return components.size == 2 && components[1] == '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}
    def resource_uri?
      return components.size == 2 && components[1] != '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions
    def version_collection_uri?
      return components.size == 3 && components[2] == 'versions'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions/_resolved
    def resolved_version_collection_uri?
      return components.size == 4 && components[2] == 'versions' && components[3] == '_resolved'
    end

    # Returns true if URI matches /{collection}/{uuid}/versions/{etag}
    def resource_version_uri?
      return components.size == 4 && components[2] == 'versions' && components[3] != '_resolved'
    end

    # Returns a cannonical URI for a given URI/URI fragment, generating it if
    # required.
    #   Example: URI.new('/items/123').cannoncal_uri_string => /items/123
    #
    #   Example: URI.new('/items').cannonical_uri_string => /items/some-new-uuid
    def cannonical_uri_string
      @cannonical_uri_string ||= if resource_collection_uri?
        "#{@string}/#{UUID.generate}"
      elsif resource_uri?
        @string
      else
        raise CloudKit::InvalidURIFormat
      end
    end
  end
end
