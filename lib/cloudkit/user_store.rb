module CloudKit

  # A thin layer on top of CloudKit::Store providing consistent URIs and
  # automatic upgrades if required for future releases.
  class UserStore
    @@store = nil

    def initialize(uri=nil)
      unless @@store
        @@store = Store.new(:collections => [:cloudkit_users])
      end
    end

    def get(uri, options={}) #:nodoc:
      @@store.get(CloudKit::URI.new(uri), options)
    end

    def post(uri, options={}) #:nodoc:
      @@store.post(CloudKit::URI.new(uri), options)
    end

    def put(uri, options={}) #:nodoc:
      @@store.put(CloudKit::URI.new(uri), options)
    end

    def delete(uri, options={}) #:nodoc:
      @@store.delete(CloudKit::URI.new(uri), options)
    end

    def resolve_uris(uris) #:nodoc:
      @@store.resolve_uris(uris.map { |uri| CloudKit::URI.new(uri) })
    end

    # Return the version for this UserStore
    def version; 1; end
  end
end
