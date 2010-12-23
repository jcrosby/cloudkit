module CloudKit

  # A MemoryTable implements the essential pieces of the Rufus Tokyo Table API
  # required for CloudKit's operation. It is basically a hash of hashes with
  # querying capabilities. None of the data is persisted to disk nor is it
  # designed with production use in mind. The primary purpose is to enable
  # testing and development with CloudKit without depending on binary Tokyo
  # Cabinet dependencies.
  #
  # Implementing a new adapter for CloudKit means writing an adapter that
  # passes the specs for this one.
  class MemoryTable

    # Create a new MemoryTable instance.
    def initialize
      @serial_id = 0
      clear
    end

    # Create a hash record for the given key. Returns the record if valid or nil
    # otherwise. Records are valid if they are hashses with both string keys and
    # string values.
    def []=(key, record)
      if valid?(record)
        @keys << key unless @hash[key]
        @hash[key] = record
      else
        raise CloudKit::InvalidRecord.new(record.inspect)
      end
    end

    # Retrieve the hash record for a given key.
    def [](key)
      @hash[key]
    end

    # Clear the contents of the store.
    def clear
      @hash = {}
      @keys = []
    end

    # Return an ordered set of all keys in the store.
    def keys
      @keys
    end

    # Generate a unique ID within the scope of this store.
    def generate_unique_id
      @serial_id += 1
    end

    # Run a query configured by the provided block. If no block is provided, all
    # records are returned. Each record contains the original hash key/value
    # pairs, plus the primary key (indexed by :pk => value).
    def query(&block)
      return @keys.map { |key| @hash[key].merge(:pk => key) } unless block
      q = MemoryQuery.new
      block.call(q)
      q.run(self)
    end

    protected 

    def valid?(record)
      return false unless record.is_a?(Hash)
      record.keys.all? { |k| k.is_a?(String) && record[k].is_a?(String) }
    end

  end

  # MemoryQuery is used internally by MemoryTable to configure a query and run
  # it against the store.
  class MemoryQuery

    # Initialize a new MemoryQuery.
    def initialize
      @conditions = []
    end

    # Run a query against the provided table using the conditions stored in this
    # MemoryQuery instance. Returns all records that match all conditions.
    # Conditions are added using #add_condition.
    def run(table)
      table.keys.inject([]) do |result, key|
        if @conditions.all? do |condition| 
            if condition[0] == 'search'
              JSON.parse(condition[2]).all? do |search_key, search_value|
                target = JSON.parse(table[key]['json'])
                search_key.split('.').each do |sub|
                  case target
                  when Hash
                    target = target[sub]
                  when Array
                    target = target.map { |item| item[sub] }.compact.flatten
                  end
                end
                case target
                when Array
                  target.any? { |item| item == search_value }
                else
                  target == search_value
                end
              end
            else
              table[key][condition[0]] == condition[2]
            end
          end
          result << table[key].merge(:pk => key)
        else
          result
        end
      end
    end

    def locate_targets(term,targets)
      case targets
      when Hash
        targets = [targets[term]]
      when Array
        targets = targets.select { |item| item.has_key?(term) }.map 
      end
    end

    # Add a condition to this query. The operator parameter is ignored at this
    # time, assuming only equality.
    def add_condition(key, operator, value)
      @conditions << [key, operator, value]
    end
  end
end
