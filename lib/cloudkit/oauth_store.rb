module CloudKit
  class OAuthStore
    @@store = nil

    def initialize(uri=nil)
      @@store = Store.new(
        :collections => [
          namespace(:nonces),
          namespace(:tokens),
          namespace(:request_tokens),
          namespace(:consumers)],
        :adapter => SQLAdapter.new(uri)) unless @@store
      load_static_consumer
    end

    def get(type, options={})
      @@store.get(namespace(type), options)
    end

    def post(type, options={})
      @@store.post(namespace(type), options)
    end

    def put(type, options={})
      @@store.put(namespace(type), options)
    end

    def delete(type, options={})
      @@store.delete(namespace(type), options)
    end

    def version; 1; end

    protected

    def load_static_consumer
      json = JSON.generate(:id => 'cloudkitconsumer', :secret => '')
      @@store.put(namespace(:consumers), :id => 'cloudkitconsumer', :data => json)
    end
    
    def namespace(key)
      "cloudkit_oauth_#{key}".to_sym
    end
  end
end
