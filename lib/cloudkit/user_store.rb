module CloudKit
  class UserStore
    @@store = nil

    def initialize(uri=nil)
      unless @@store
        login_view = ExtractionView.new(
          :cloudkit_login_view,
          :observe => :cloudkit_users,
          :extract => [:identity_url, :remember_me_token, :remember_me_expiration])
        @@store = Store.new(
          :collections => [:cloudkit_users],
          :views       => [login_view],
          :adapter     => SQLAdapter.new(uri))
      end
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

    def version; 1; end
  end
end
