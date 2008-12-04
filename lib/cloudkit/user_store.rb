module CloudKit
  class UserStore
    @@store = nil

    def initialize(uri=nil)
      unless @@store
        login_view = ExtractionView.new(
          namespace(:login_view),
          :observe => namespace(:users),
          :extract => [:identity_url, :remember_me_token, :remember_me_expiration])
        @@store = Store.new(
          :collections => [namespace(:users)],
          :views       => [login_view],
          :adapter     => SQLAdapter.new(uri))
      end
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

    def namespace(key)
      "cloudkit_#{key}".to_sym
    end
  end
end
