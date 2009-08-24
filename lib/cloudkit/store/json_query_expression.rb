module CloudKit
  class JSONQueryExpression

    attr_reader :string
    attr_reader :escaped_string

    def initialize(string)
      @escaped_string = string
      @string = Rack::Utils.unescape(@escaped_string)
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
      @slice_expressions ||= @parts.select do |part|
        part.match(/^\[((\d*:\d*)|(\d+))\]$/)
      end
    end

    def [](index)
      @parts[index] rescue nil
    end

    def chopped
      @chopped ||= @parts[0..-2].join
    end

    def array_slice_operator?
      size == 1 and @string == slice_expressions[0]
    end

    def last
      @parts[-1] rescue nil
    end

    def has_trailing_slice_operator?
      slice_expressions.include?(last)
    end

    def self.extract_start(expression)
      return 0 unless expression.match(/^\[\d*:\d*\]$/) # TODO fix and extract regex
      expression.match(/\d+/)[0].to_i rescue 0 # TODO don't assume there is a start
    end

    def self.extract_end(expression)
      return -1 unless expression.match(/^\[\d*:\d*\]$/) # TODO fix and extract regex
      expression.sub('[','').sub(']', '').split(':')[1].to_i rescue -1 # TODO don't assume there is an end
    end
  end
end
