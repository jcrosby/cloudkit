module CloudKit
  class SQLAdapter < Adapter
    def initialize(config=nil, options={})
      @db = config ? Sequel.connect(config, options) : Sequel.sqlite
      # TODO accept views as part of a store, then initialize them here
      initialize_storage
    end

    def method_missing(method, *args, &block)
      @db.send(method, *args, &block)
    end

    protected

    def initialize_storage
      @db.create_table store_key do
        primary_key :id
        varchar     :uri, :unique => true
        varchar     :etag
        varchar     :collection_reference
        varchar     :resource_reference
        varchar     :last_modified
        varchar     :remote_user
        text        :content
        boolean     :deleted, :default => false
      end unless @db.table_exists?(store_key)
    end
  end
end
