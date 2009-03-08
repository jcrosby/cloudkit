module CloudKit
  class Resource

    attr_reader :uri, :etag, :last_modified, :json, :remote_user

    def initialize(uri, json, remote_user=nil, options={})
      load_from_options(options.merge(
        :uri         => uri,
        :json        => json,
        :remote_user => remote_user))
    end

    def save
      @id ||= '%064d' % CloudKit.storage_adapter.generate_unique_id
      @etag = UUID.generate unless @deleted
      @last_modified = Time.now.httpdate

      CloudKit.storage_adapter[@id] = {
        'uri'                  => @uri.cannonical_uri_string,
        'etag'                 => escape(@etag),
        'last_modified'        => @last_modified,
        'json'                 => @json,
        'deleted'              => escape(@deleted),
        'archived'             => escape(@archived),
        'remote_user'          => escape(@remote_user),
        'collection_reference' => @collection_reference ||= @uri.collection_uri_fragment,
        'resource_reference'   => @resource_reference ||= @uri.cannonical_uri_string
      }.merge(escape_values(parsed_json))
      reload
    end

    def update(json, remote_user=nil)
      raise HistoricalIntegrityViolation unless current?
      CloudKit.storage_adapter.transaction do
        record = CloudKit.storage_adapter[@id]
        record['uri'] = "#{@uri.string}/versions/#{@etag}"
        record['archived'] = escape(true)
        CloudKit.storage_adapter[@id] = record
        self.class.create(@uri, json, remote_user || @remote_user)
      end
      reload
    end

    def delete
      raise HistoricalIntegrityViolation unless current?
      CloudKit.storage_adapter.transaction do
        original_uri = @uri
        record = CloudKit.storage_adapter[@id]
        record['uri'] = "#{@uri.string}/versions/#{@etag}"
        record['archived'] = escape(true)
        @uri = wrap_uri(record['uri'])
        @archived = unescape(record['archived'])
        CloudKit.storage_adapter[@id] = record
        self.class.new(original_uri, @json, @remote_user, {:deleted => true}).save
      end
      reload
    end

    def versions
      # TODO make this a collection proxy, only loading the first, then the
      # rest as needed during iteration (possibly in chunks)
      return nil if @archived
      @versions ||= [self].concat(CloudKit.storage_adapter.query { |q|
        q.add_condition('resource_reference', :eql, @resource_reference)
        q.add_condition('archived', :eql, 'true')
      }.reverse.map { |hash| self.class.build_from_hash(hash) })
    end

    def previous_versions
      @previous_versions ||= versions[1..-1] rescue []
    end

    def previous_version
      @previous_version ||= previous_versions[0]
    end

    def deleted?
      @deleted
    end

    def archived?
      @archived
    end
    
    def current?
      !@deleted && !@archived
    end

    def parsed_json
      @parsed_json ||= JSON.parse(@json)
    end

    def self.create(uri, json, remote_user=nil)
      resource = new(uri, json, remote_user)
      resource.save
      resource
    end

    def self.current(spec={})
      all({:deleted => false, :archived => false}.merge(spec))
    end

    def self.all(spec={})
      CloudKit.storage_adapter.query { |q|
        spec.keys.each { |k|
          q.add_condition(k.to_s, :eql, escape(spec[k]))
        }
      }.reverse.map { |hash| build_from_hash(hash) }
    end

    def self.first(spec)
      all(spec)[0]
    end

    protected

    def load_from_options(opts)
      options = symbolize_keys(opts)

      @uri                  = wrap_uri(options[:uri])
      @json                 = options[:json]
      @last_modified        = options[:last_modified]
      @resource_reference   = options[:resource_reference]
      @collection_reference = options[:collection_reference]
      @id                   = options[:id] || options[:pk] || nil
      @etag                 = unescape(options[:etag])
      @remote_user          = unescape(options[:remote_user])
      @archived             = unescape(options[:archived]) || false
      @deleted              = unescape(options[:deleted]) || false
    end

    def reload
      result = CloudKit.storage_adapter.query { |q|
        q.add_condition('uri', :eql, @resource_reference)
      }
      load_from_options(result[0])
    end

    def self.build_from_hash(data)
      new(
        data['uri'],
        data['json'],
        data['remote_user'],
        {}.filter_merge!(
          :etag                 => data['etag'],
          :last_modified        => data['last_modified'],
          :resource_reference   => data['resource_reference'],
          :collection_reference => data['collection_reference'],
          :id                   => data[:pk],
          :deleted              => data['deleted'],
          :archived             => data['archived']))
    end

    def wrap_uri(uri)
      self.class.wrap_uri(uri)
    end

    def self.wrap_uri(uri)
      case uri
        when CloudKit::URI; uri
        else CloudKit::URI.new(uri)
      end
    end

    def scope(key)
      "#{@id}:#{key}"
    end

    def escape(value)
      self.class.escape(value)
    end

    def self.escape(value)
      case value
      when TrueClass
        "true"
      when FalseClass
        "false"
      when NilClass
        "null"
      when Fixnum, Bignum, Float
        value.to_s
      else
        value
      end
    end

    def unescape(value)
      self.class.unescape(value)
    end

    def self.unescape(value)
      case value
      when "true"
        true
      when "false"
        false
      when "null"
        nil
      else
        value
      end
    end

    def symbolize_keys(hash)
      hash.inject({}) { |memo, pair| memo.merge({pair[0].to_sym => pair[1]}) }
    end

    def escape_values(hash)
      hash.inject({}) { |memo, pair| memo.merge({pair[0] => escape(pair[1])}) }
    end
  end
end
