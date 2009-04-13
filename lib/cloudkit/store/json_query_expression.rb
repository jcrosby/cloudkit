module CloudKit
  class JSONQueryExpression

    attr_reader :string
    attr_reader :escaped_string

    def initialize(string)
      @escaped_string = string
      @string = Rack::Utils.unescape(string)
      @parts = @string.scan(/\[.*?\]/)
    end

    def self.from_escaped_path(path)
      expression = path.match(/%5B.*%5D$/)[0] rescue (return nil)
      new(expression)
    end

    def size
      @parts.size
    end

    def slice_expressions
      @parts.select do |part|
        part.match(/^\[\d*:\d*\]$/)
      end
    end

    def [](index)
      @parts[index] rescue nil
    end
  end
end
