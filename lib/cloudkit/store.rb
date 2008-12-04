module CloudKit
  #
  # A storage interface with HTTP semantics and pluggable adapters.
  #
  class Store
    include ResponseHelpers
    include Validators
    include GetHelpers

    def initialize(options)
      @db    = options[:adapter] || SQLAdapter.new
      @types = options[:collections]
      @views = options[:views]
      @types.each {|type| create_storage(type)} if @types
      @views.each {|view| view.create_storage(@db)} if @views
    end

    def get(type, options={})
      return invalid_entity_type unless valid_entity_type?(type)
      normalize(options)
      [
        :resource_history,
        :collection,
        :current_resource,
        :resource_version,
        :removed_resource
      ].inject(nil) do |res, method|
        res || send(method, type, options)
      end || status_404
    end

    def put(type, options={})
      return invalid_entity_type unless @types.include?(type)
      error = check(options, :no_if_none_match, :has_data)
      return error if error
      data = JSON.parse(options[:data]) rescue (return status_422)
      return id_required unless options[:id] && data['id']
      return id_mismatch unless data['id'] == options[:id]
      normalize(options)
      data['last_modified'] = timestamp
      resource = @db[type].filter(:id => data['id'])
      if resource.any?
        update_resource(resource, type, options, data)
      else
        create_resource(type, options, data)
      end
    end

    def post(type, options={})
      return invalid_entity_type unless @types.include?(type)
      error = check(options, :no_if_none_match, :has_data)
      return error if error
      data = JSON.parse(options[:data]) rescue (return status_422)
      data['id'] = UUID.generate
      data['last_modified'] = timestamp
      data['etag'] = build_etag(data)
      map(type, data)
      @db[type].insert(identify(
        options,
        :id            => data['id'],
        :etag          => data['etag'],
        :last_modified => data['last_modified'],
        :content       => JSON.generate(data)))
      response(201, json_id(data['id']), data['etag'], data['last_modified'])
    end

    def delete(type, options={})
      return invalid_entity_type unless @types.include?(type)
      error = check(options, :no_if_none_match, :has_id)
      return error if error
      normalize(options)
      return etag_required unless options[:etag]
      result = delete_resource(type, options)
      return result if result
      id_check = @db[type].filter(identify(options, :id => options[:id]))
      return status_412 if id_check.any?
      etag_check = @db[self.class.history(type)].filter(:entity_id => options[:id])
      return status_410 if etag_check.any?
      status_404
    end

    def meta(type, options={})
      result = @db[type]
      if ([:etag, :remote_user].any?{|k| options[k]} || is_view?(type))
        result = result.filter(options.reject{|k,v| k == :if_none_match})
      end
      result = result.map do |r|
        JSON.generate(
          :id            => r[:id],
          :etag          => r[:etag],
          :last_modified => r[:last_modified])
      end.join(",\n") || []
      response(200, json_list(result))
    end

    def etags(type, options={})
      return invalid_entity_type unless @types.include?(type)
      return id_required unless options[:id]
      options = options.reject{|k,v| k == :if_none_match}
      current = @db[type].filter(identify(options, :id => options[:id]))
      history = @db[self.class.history(type)].filter(
        identify(options, :entity_id => options[:id])).reverse_order(:id)
      versions = current.all
      versions.concat(history.all)
      return status_404 unless versions.any?
      result = versions.map{|r| JSON.generate(:etag => r[:etag])}.join(",\n") || []
      response(200, json_list(result))
    end

    def version; 1; end

    def self.history(type)
      "#{type}_history".to_sym
    end

    def self.current(type)
      type.to_s.sub(/_history?/, '').to_sym
    end

    protected

    def update_resource(resource, type, options, data)
      unless resource.first[:remote_user] == options[:remote_user]
        return status_404
      end if (options[:remote_user])
      return etag_required unless options[:etag] && data['etag']
      return etag_mismatch unless options[:etag].first == data['etag']
      return status_412 unless data['etag'] == resource.first[:etag]
      data['etag'] = build_etag(data)
      original = @db[type].filter(:id => data['id'])
      map(type, data)
      @db[self.class.history(type)].insert(
        :entity_id     => data['id'],
        :etag          => resource.first[:etag],
        :created       => data['last_modified'],
        :last_modified => resource.first[:last_modified],
        :remote_user   => resource.first[:remote_user],
        :content       => resource.first[:content])
      original.update(
        :etag          => data['etag'],
        :last_modified => data['last_modified'],
        :content       => JSON.generate(data))
      response(
        200,
        json_id(data['id']),
        data['etag'],
        data['last_modified'])
    end

    def create_resource(type, options, data)
      data['etag'] = build_etag(data)
      map(type, data)
      @db[type].insert(identify(
        options,
        :id            => data['id'],
        :etag          => data['etag'],
        :last_modified => data['last_modified'],
        :content       => JSON.generate(data)))
      response(
        201,
        json_id(data['id']),
        data['etag'],
        data['last_modified'])
    end

    def delete_resource(type, options)
      resource = @db[type].filter(options)
      if resource.any?
        deleted = timestamp
        unmap(type, options[:id])
        @db[self.class.history(type)].insert(
          :entity_id     => options[:id],
          :etag          => resource.first[:etag],
          :created       => deleted,
          :last_modified => resource.first[:last_modified],
          :remote_user   => resource.first[:remote_user],
          :content       => resource.first[:content])
        result = resource.delete
        response(200, '', nil, deleted)
      end
    end

    def db; @db; end

    def normalize(options)
      options.rekey!(:if_match, :etag)
      [:etag, :if_none_match].each do |k|
        options.delete[k] if options[k] == '*'
        options[k] &&= [options[k]] unless options[k].is_a?(Array)
      end
    end

    def is_view?(type)
      @views && @views.map{|v| v.name}.include?(type)
    end

    def is_history?(type)
      @types && @types.map{|t| self.class.history(t)}.include?(type)
    end

    def valid_entity_type?(type)
      @types.include?(type) || is_view?(type) || is_history?(type)
    end

    def map(type, data)
      @views.each{|view| view.map(@db, type, data)} if @views
    end

    def unmap(type, id)
      @views.each{|view| view.unmap(@db, type, id)} if @views
    end

    def timestamp
      Time.now.httpdate
    end

    def identify(options, data={})
      data.filter_merge!(:remote_user => options[:remote_user])
    end

    def build_etag(data)
      MD5::md5(data.to_s).hexdigest
    end

    def create_storage(type)
      @db.create_table type do
        varchar :id
        varchar :etag
        varchar :last_modified
        varchar :remote_user
        text    :content
        index   :id
        index   :remote_user
      end unless @db.table_exists?(type)
      @db.create_table self.class.history(type) do
        primary_key :id # auto-incremented, store-scoped version ordering
        varchar     :entity_id
        varchar     :etag
        varchar     :created # needed for delete timestamps
        varchar     :last_modified
        varchar     :remote_user
        text        :content
        index       :id
        index       :entity_id
        index       :etag
        index       :remote_user
      end unless @db.table_exists?(self.class.history(type))
    end
  end
end
