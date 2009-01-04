module CloudKit

  # Adapts a CloudKit::Store to a SQL backend.
  class SQLAdapter < Adapter

    # Initialize a new SQL backend. Defaults to in-memory SQLite.
    def initialize(uri=nil, options={})
      @db = uri ? Sequel.connect(uri, options) : Sequel.sqlite
      # TODO accept views as part of a store, then initialize them here
      initialize_storage
    end

    # method_missing is a placeholder for future interface extraction into
    # CloudKit::Adapter.
    def method_missing(method, *args, &block)
      @db.send(method, *args, &block)
    end

    protected

    # Initialize the HTTP-oriented storage if it does not exist.
    def initialize_storage
      @db.create_table CLOUDKIT_STORE do
        primary_key :id
        varchar     :uri, :unique => true
        varchar     :etag
        varchar     :collection_reference
        varchar     :resource_reference
        varchar     :last_modified
        varchar     :remote_user
        text        :content
        boolean     :deleted, :default => false
      end unless @db.table_exists?(CLOUDKIT_STORE)
    end
  end
end
