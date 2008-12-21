module CloudKit

  # A thin layer on top of CloudKit::Store providing consistent URIs and
  # automatic schema upgrades if required for future releases.
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

    def get(uri, options={}) #:nodoc:
      @@store.get(uri, options)
    end

    def post(uri, options={}) #:nodoc:
      @@store.post(uri, options)
    end

    def put(uri, options={}) #:nodoc:
      @@store.put(uri, options)
    end

    def delete(uri, options={}) #:nodoc:
      @@store.delete(uri, options)
    end

    def resolve_uris(uris) #:nodoc:
      @@store.resolve_uris(uris)
    end

    # Return the version for this UserStore
    def version; 1; end
  end
end
