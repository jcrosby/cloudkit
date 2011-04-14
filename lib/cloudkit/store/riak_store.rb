require 'set'
require 'riak'
require 'pp'

module CloudKit
  class RiakStore

    def initialize
      @client = Riak::Client.new
      @doc_bucket = @client.bucket('docs')
    end

    def []=(pk,record)
      if pk && valid?(record)
        obj = @doc_bucket.get_or_new(pk)
        obj.data = record
        obj.store
      else
        raise CloudKit::InvalidRecord.new("pk (#{pk.to_s}) bad or Invalid Record: #{record.inspect}")
      end
    end

    def [](pk)
      begin
        obj = @doc_bucket.get(pk)
      rescue Riak::FailedRequest => fr
      end
      obj.data if obj
    end

    def keys
      @doc_bucket.keys.inject([]) { |acc,keys| acc << keys }.flatten
    end

    def valid?(record)
      return false unless record.is_a?(Hash)
      record.keys.all? { |k| k.is_a?(String) && record[k].is_a?(String) }
    end

    def query(&block)
      q = RiakQuery.new
      block.call(q)
      q.run(self)
    end

    def clear
      @doc_bucket.keys { |keys| keys.each { |key| @doc_bucket.delete(key) } }
    end
  end

  class RiakQuery

    def initialize
      @conditions = []
    end

    def run(table)
    end

    def add_condition(key, operator, value)
      @conditions << [key, operator, value]
    end
  end
end
