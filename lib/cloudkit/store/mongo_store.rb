require 'mongo'
require 'bson'

module CloudKit
  class MongoStore

    attr_reader :db

    # Creates a MongoStore, setting up the db and internal meta_collection if necessary
    #
    # Any options not listed below are passed as options to Mongo::Connection.multi
    #
    # @param [Hash] options
    #
    # @option options [String] :db_name (cloudkit) the name of the mongo db to use.
    # @option options [Array] :hosts ([ ['localhost', 27017] ]) the array of arrays listing the [ host, port ] to connect to
    # @option options [Hash] :custom_indexes a Hash of Arrays of values that will be passed to create_index, keyed on the collection name
    # @option options [Hash] :sage_write_options ({{ :fsync => true, :w => (@hosts.length > 1) ? 2 : 1, :wtimeout => 25000 }) a Hash to be passed into Mongo write operations
    #
    def initialize(options = {})
      @db_name = options.delete(:db_name) { |key|  'cloudkit' }
      @collection_name = options.delete(:collection_name) { |key| 'collections' }
      @hosts = options.delete(:hosts) { |key| [ ['localhost',27017] ] }
      @safe_write_options = options.delete(:safe_write_options) { |key| { :fsync => true, :w => (@hosts.length > 1) ? 2 : 1, :wtimeout => 25000 } }
      @custom_indexes = options.delete(:custom_indexes) { |key| Hash.new }
      @connection = Mongo::Connection.multi(@hosts, options)

      setup_db
      setup_meta
    end

    # Retry the connection in case of a failure.
    # With this we can retry an operation against other members of a replica set.
    #
    # @param [Integer] max_retries (5) the maximum number of retries before re-raising the error
    #
    # @param [Float, Integer] sleep_time (1.0) the amount of time to sleep between retries
    #
    # @raise [Mongo::ConnectionFailure] if the number of retries >= max_retries
    #
    # @return the results of the block
    def rescue_connection_failure(max_retries=5, sleep_time=1.0)
      retries = 0
      while true
        begin
          return yield
        rescue Mongo::ConnectionFailure => ex
          retries += 1
          raise ex if retries >= max_retries
          sleep(sleep_time)
        end
      end
    end

    # Ensure the write goes to multiple servers, if there are multiple hosts
    #
    # NOTE: This is ONLY used to wrap find_and_modify atm, since it appears the driver's find_and_modify command
    #       does not support the write options (yet).
    #
    # @param [Integer] count (2) the number of servers the write needs to go to before being considered complete
    #
    # @param [Integer] timeout (30000) the timeout before raising an error
    #
    # @raise [Mongo::OperationFailure] if the write times out writing to count hosts
    #
    # @return the results of the block
    def ensure_multi_write
      rescue_connection_failure do
        block_result = yield
        unless @hosts.length == 1
          validate_write_cmd = BSON::OrderedHash.new
          validate_write_cmd[:getlasterror] = 1
          validate_write_cmd[:w] = @safe_write_options[:w]
          validate_write_cmd[:wtimeout] = @safe_write_options[:wtimeout]
          validate_write_result = @db.command( validate_write_cmd )
          unless validate_write_result["ok"] == 1
            raise Mongo::OperationFailure, "unable to write to #{count} hosts within timeout (#{timeout}): #{validate_write_result['errmsg']}"
          end
        end
        block_result
      end
    end

    # Given a query (or a record) what is the name of the Mongo collection
    #
    # If it can't figure out the collection it returns a default of 'default'
    #
    # @param [Hash] query the query/record in question
    #
    # @raise [Mongo::OperationFailure] if it can't figure out the collection name
    #
    # @return [String] the name of the collection
    def collection_name_for_query(query)
      if query.keys.include?('collection_reference')
        query['collection_reference'].split('/')[1]
      elsif query.keys.include?('resource_reference')
        query['resource_reference'].split('/')[1]
      elsif query.keys.include?('uri')
        query['uri'].split('/')[1]
      else
        'default'
      end
    end

    # Given a query (or a record) return the Mongo collection.
    #
    # Sets up the collection and it's indexes if it isn't already setup.
    #
    # @param [Hash] query the query/record in question
    #
    # @return [Mongo::Collection] the Mongo collection for the query/record
    def collection_for_query(query)
      collection_name = collection_name_for_query(query)
      unless @db.collection_names.include?(collection_name)
        setup_collection(collection_name)
      end
      @db[collection_name]
    end

    # Given a collection name, return the Mongo collection
    #
    # Sets up the collection and it's indexes if it isn't already setup.
    #
    # @param [String] name the name of the Mongo Collection
    #
    # @return [Mongo::Collection] the named Mongo collection
    def collection_by_name(name)
      unless @db.collection_names.include?(name)
        setup_collection(name)
      end
      @db[name]
    end

    # Sets a record with a given primary key
    #
    # @param [String] pk the cloudkit primary key
    # @param [Hash] record the record to save to this primary key
    #
    # @return [Hash] the saved record

    def []=(pk,record)
      if pk && valid?(record)
        # Find the collection for this record
        collection = collection_for_query(record)

        # If the document already exists, look it up
        original = lookup_by_pk(pk)

        # If it already exists, then we are updating an existing object, so extract the Mongo Id, otherwise create a new one
        oid = original.nil? ? BSON::ObjectId.new : original["_id"]

        # Add the pk and the oid to the record, we'll need them later
        record.merge!(:pk => pk)
        record.merge!(:_id => oid)

        # convert the string to JSON so MongoDB can DTRT
        if record['json'].is_a?(String)
          record['json'] = JSON.parse(record['json'])
        end

        # Write the record with an upsert

        collection.update( {:_id => oid}, record, :upsert => true, :safe => @safe_write_options )

        # if the item is new record it in the meta collection so we can find it later.
        unless original
          @meta_pk_collection.save( { :pk => pk, :mongo_id => oid, :collection => collection.name }, :safe => @safe_write_options )
        end

        record
      else
        nil
      end
    end

    # Strips out (or normalizes) bits that cloudkit doesn't want
    #
    # @param [Hash] result The result to strip
    # @param [Boolean] remove_pk Also strip out the primary key, sometimes cloudkit doesn't want this
    #
    # @return [Hash] the stripped record
    def _fix_up_result(result,remove_pk = false)
      if remove_pk
        result.delete(:pk)
        result.delete('pk')
      else
        if v = result.delete('pk')
          result[:pk] = v
        end
      end
      result.delete('_id')
      # convert the json to a string so CloudKit DTRT
      if result["json"].is_a?(Hash)
        result["json"] = result["json"].to_json
      end
      result
    end

    # Clear the Mongo databases
    def clear
      drop_all_collections_in(@db_name)
      setup_db
      drop_all_collections_in(@meta_db_name)
      setup_meta
    end

    # Returns the primary keys, as seen by cloudkit
    def keys
      #FIXME: Does the order of the keys really matter?
      @meta_pk_collection.distinct("pk").compact
    end

    # Cloudkit public API support for looking up an item by primary key, with fixups
    def [](pk)
      if result = lookup_by_pk(pk)
        _fix_up_result(result,true)
      end
      result
    end

    # Generate a unique id
    # uses and internal counter that is saved in the meta_counter_collection
    def generate_unique_id
      result = ensure_multi_write { @meta_counter_collection.find_and_modify(:query => { :name => 'primary_key_counter' },
                                                                             :update => { '$inc' => { 'counter' => 1 } },
                                                                             :new => true
                                                                            )
                                   }
      result["counter"]
    end

    # Query the store
    #
    # Calling w/o a block should return all records in all collections
    #
    # @param [Block] block Query block
    #
    # @return [Array] results of the query
    def query(&block)
      # Return everything if there isn't a block. expensive!
      unless block
        return rescue_connection_failure { @db.collections.select { |collection| collection.name != 'system.indexes' }.
                                           map { |collection| collection.find().map{ |result| _fix_up_result(result) } }.flatten
                                         }
      end

      #Otherwise construct and run a query.
      q = MongoQuery.new
      block.call(q)
      q.run(self)
    end

    protected

    # Lookup an item by cloudkit's primary key, don't fixup
    def lookup_by_pk(pk)
      if meta_result = rescue_connection_failure { @meta_pk_collection.find_one( :pk => pk ) }
        rescue_connection_failure { collection_by_name(meta_result['collection']).find_one( :_id => meta_result['mongo_id'] ) }
      end
    end

    # Is the record valid?
    #
    # Very simple checks,
    #  ... stolen from CloudKit::MemoryTable
    #
    # @param [Hash] record The record to check for validity
    def valid?(record)
      return false unless record.is_a?(Hash)
      record.keys.all? { |k| k.is_a?(String) && ( record[k].is_a?(String) || record[k].is_a?(BSON::ObjectId) ) }
    end

    private

    # Setup the primary collection database
    def setup_db
      @db = @connection.db(@db_name)
    end

    # Setup a collection
    def setup_collection(collection_name)
      collection = @db[collection_name]
      setup_pk_query_index(collection)
      setup_uri_query_index(collection)
      setup_item_query_index(collection)
      setup_collection_get_index(collection)
      setup_item_versions_get_index(collection)
      setup_custom_indexes(collection)
    end

    # Setup the custom indexes for a collection
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup
    def setup_custom_indexes(collection)
      if custom_indexes = @custom_indexes[collection.name]
        custom_indexes.each do | custom_index |
          collection.create_index(*custom_index)
        end
      end
    end

    # Index for cloudkit PKs
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_pk_query_index(collection)
      collection.create_index([['pk', Mongo::ASCENDING]], { :unique => true, :background => true })
    end

    # Index for straight uri queries
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_uri_query_index(collection)
      collection.create_index([['uri', Mongo::ASCENDING]], { :background => true })
    end

    # Index for item (uri + remote_user) queries
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_item_query_index(collection)
      collection.create_index([['uri', Mongo::ASCENDING],
                               ['remote_user', Mongo::ASCENDING]
                              ], { :background => true })
    end

    # Index for collection GETs (collection_reference + archived + deleted + remote_user) queries
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_collection_get_index(collection)
      collection.create_index([['collection_reference', Mongo::ASCENDING],
                               ['archived', Mongo::ASCENDING],
                               ['deleted', Mongo::ASCENDING],
                               ['remote_user', Mongo::ASCENDING]
                              ], { :background => true })
    end

    # Index for item/version GETs (deleted, remote_user, resource_reference) queries
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_item_versions_get_index(collection)
      collection.create_index([['deleted', Mongo::ASCENDING],
                               ['remote_user', Mongo::ASCENDING],
                               ['resource_reference', Mongo::ASCENDING]
                              ], {:background => true } )
    end

    # Index for DELETE
    # Note: the delete processes also uses some of the above indexes
    #
    # @param [Mongo::Collection] collection The Mongo collection to setup the index on
    def setup_delete_index(collection)
      collection.create_index([['archives', Mongo::ASCENDING],
                               ['resource_reference', Mongo::ASCENDING]
                              ], {:background => true } )
    end

    # Sets up the meta collection that Mongo Store uses internally.
    def setup_meta
      @meta_db_name = "__#{@db_name}__meta__"
      @meta_pk_collection = @connection.db(@meta_db_name)['pk']
      @meta_counter_collection = @connection.db(@meta_db_name)['counter']
      if @meta_counter_collection.find( :name => 'primary_key_counter').count == 0
        @meta_counter_collection.insert( { :name => 'primary_key_counter', :counter => 0 }, :safe => @safe_write_options )
      end

      setup_meta_collection_indexes
    end

    # Index how we use the meta collection
    def setup_meta_collection_indexes
      @meta_counter_collection.create_index([['name', Mongo::ASCENDING]], {:background => true })
      @meta_pk_collection.create_index([['pk', Mongo::ASCENDING]], {:background => true })
    end

    # Drops all collections for the given database name
    #
    # @param [String] database_name The name of the database whose collections will be dropped
    def drop_all_collections_in(database_name)
      @connection[database_name].collection_names.reject {|c| c =~ /^system\./ }.each {|c| @connection[database_name].drop_collection(c) }
    end
  end


  # Encapsulates query behavior
  class MongoQuery

    def initialize
      @conditions = []
    end

    # Runs the query
    # Usually called only by Cloudkit::MongoStore.query
    #
    # @param [Cloudkit::MongoStore] table The store that will run the query
    def run(table)
      # FIXME: Only really supports :eql atm ... but that's seems to be all the Cloudkit generates atm
      query = @conditions.inject({}) do |fquery, condition|
        if condition[0] == 'search'
          search_conditions = JSON(condition[2])
          search_conditions.each do |key, value|
            fquery.update("json.#{key}" => value)
          end
          fquery
        else
          fquery.merge( { condition[0] => condition[2] } )
        end
      end
      table.rescue_connection_failure { table.collection_for_query(query).find(query).map { |result| table._fix_up_result(result) } }
    end

    # Gets called for each condition.
    # Used to construct the query
    #
    # @param [String] key the key to check
    # @param [Symbol] operator the operator, always :eql atm
    # @param [String] value the value to match
    def add_condition(key, operator, value)
      @conditions << [key, operator, value]
    end

  end
end
