module CloudKit
  class Response
    attr_reader :status, :meta, :content

    def initialize(status, meta, content)
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
  end
end
