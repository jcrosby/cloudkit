module CloudKit
  class MemoryTable

    def initialize
      @serial_id = 0
      clear
    end

    def []=(key, record)
      if valid?(record)
        @keys << key unless @hash[key]
        return @hash[key] = record
      end
      nil
    end

    def [](key)
      @hash[key]
    end

    def clear
      @hash = {}
      @keys = []
    end

    def keys
      @keys
    end

    def generate_unique_id
      @serial_id += 1
    end

    def query(&block)
      return @keys.map { |key| @hash[key].merge(:pk => key) } unless block
      q = MemoryQuery.new
      block.call(q)
      q.run(self)
    end

    def transaction
      yield
    end

    protected 

    def valid?(record)
      return false unless record.is_a?(Hash)
      record.keys.all? { |k| k.is_a?(String) && record[k].is_a?(String) }
    end

  end

  class MemoryQuery

    def initialize
      @conditions = []
    end

    def run(table)
      table.keys.inject([]) do |result, key|
        if @conditions.all? { |condition| table[key][condition[0]] == condition[2] }
          result << table[key].merge(:pk => key)
        else
          result
        end
      end
    end

    def add_condition(key, operator, value)
      @conditions << [key, operator, value]
    end
  end
end
