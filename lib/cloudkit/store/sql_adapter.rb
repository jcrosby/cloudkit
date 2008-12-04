module CloudKit
  class SQLAdapter < Adapter
    def initialize(config=nil, options={})
      @db = config ? Sequel.connect(config, options) : Sequel.sqlite
    end

    def method_missing(method, *args, &block)
      @db.send(method, *args, &block)
    end
  end
end
