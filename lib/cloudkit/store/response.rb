module CloudKit
  class Response
    include Util

    attr_reader :status, :meta, :content

    def initialize(status, meta, content='')
      @status = status; @meta = meta; @content = content
    end

    def [](key)
      meta[key]
    end

    def []=(key, value)
      meta[key] = value
    end

    def to_rack
      [status, meta, [content]]
    end

    def parsed_content
      JSON.parse(content)
    end

    def clear_content
      @content = ''
    end

    def head
      response = self.dup
      response.clear_content
      response
    end

    def etag
      unquote(meta['ETag'])
    end
  end
end
