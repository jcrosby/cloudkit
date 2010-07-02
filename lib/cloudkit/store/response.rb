module CloudKit

  # A response wrapper for CloudKit::Store
  class Response
    include Util

    attr_reader :status, :meta, :content

    # Create an instance of a Response.
    def initialize(status, meta, content='')
      @status = status; @meta = meta; @content = content
    end

    # Return the header value specified by key.
    def [](key)
      meta[key]
    end

    def to_i
      @status
    end

    # Set the header specified by key to value.
    def []=(key, value)
      meta[key] = value
    end

    # Translate to the standard Rack representation: [status, headers, content]
    def to_rack
      meta['Content-Length'] = content.length.to_s
      [status, meta, [content.to_s]]
    end

    # Parse and return the JSON content
    def parsed_content
      JSON.parse(content)
    end

    # Clear only the content of the response. Useful for HEAD requests.
    def clear_content
      @content = ''
    end

    # Return a response suitable for HEAD requests.
    def head
      response = self.dup
      response.clear_content
      response
    end

    # Return the ETag for this response without the surrounding quotes.
    def etag
      unquote(meta['ETag'])
    end
  end
end
