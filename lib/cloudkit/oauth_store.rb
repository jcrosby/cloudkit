module CloudKit
  class OAuthStore
    @@store = nil

    def initialize(uri=nil)
      @@store = Store.new(
        :collections => [
          :cloudkit_oauth_nonces,
          :cloudkit_oauth_tokens,
          :cloudkit_oauth_request_tokens,
          :cloudkit_oauth_consumers],
        :adapter => SQLAdapter.new(uri)) unless @@store
      load_static_consumer
    end

    def get(uri, options={})
      @@store.get(uri, options)
    end

    def post(uri, options={})
      @@store.post(uri, options)
    end

    def put(uri, options={})
      @@store.put(uri, options)
    end

    def delete(uri, options={})
      @@store.delete(uri, options)
    end

    def resolve_uris(uris)
      @@store.resolve_uris(uris)
    end
    
    def reset!
      @@store.reset!
    end

    def version; 1; end

    def load_static_consumer
      json = JSON.generate(:secret => '')
      @@store.put('/cloudkit_oauth_consumers/cloudkitconsumer', :json => json)
    end
  end
end
