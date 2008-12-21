require 'openid/store/interface'
module CloudKit
  class OpenIDStore < OpenID::Store::Interface
    @@store = nil

    def initialize(uri=nil)
      unless @@store
        association_view = ExtractionView.new(
          :cloudkit_openid_server_handles,
          :observe => :cloudkit_openid_associations,
          :extract => [:server_url, :handle])
        @@store = Store.new(
          :collections => [:cloudkit_openid_associations, :cloudkit_openid_nonces],
          :views       => [association_view],
          :adapter     => SQLAdapter.new(uri))
      end
    end

    def get_association(server_url, handle=nil)
      options = {:server_url => server_url}
      options.merge!(:handle => Base64.encode64(handle)) if (handle && handle != '')
      result = @@store.get('/cloudkit_openid_server_handles', options)
      return nil unless result.status == 200
      return nil if result.parsed_content['total'] == 0

      ignore, associations = resolve_associations(result.parsed_content)
      return nil if associations.empty?

      associations.sort_by{|a| a['issued']}
      a = associations[-1]
      OpenID::Association.new(
        Base64.decode64(a['handle']),
        Base64.decode64(a['secret']),
        Time.at(a['issued']),
        a['lifetime'],
        a['assoc_type'])
    end

    def remove_association(server_url, handle)
      result = @@store.get(
        '/cloudkit_openid_server_handles',
        :server_url => server_url,
        :handle     => Base64.encode64(handle))
      return nil unless result.status == 200

      responses, associations = resolve_associations(result.parsed_content)
      return nil if associations.empty?

      uris = result.parsed_content['uris']
      responses.each_with_index do |r, index|
        @@store.delete(uris[index], :etag => r.etag)
      end
    end

    def store_association(server_url, association)
      remove_association(server_url, association.handle)
      json = JSON.generate(
        :server_url => server_url,
        :handle     => Base64.encode64(association.handle),
        :secret     => Base64.encode64(association.secret),
        :issued     => association.issued.to_i,
        :lifetime   => association.lifetime,
        :assoc_type => association.assoc_type)
      result = @@store.post('/cloudkit_openid_associations', :json => json)
      return (result.status == 201)
    end

    def use_nonce(server_url, timestamp, salt)
      return false if (timestamp - Time.now.to_i).abs > OpenID::Nonce.skew

      fragment = URI.escape([server_url, timestamp, salt].join('-'))
      uri      = "/cloudkit_openid_nonces/#{fragment}"
      result   = @@store.put(uri, :json => '{}')
      return (result.status == 201)
    end

    def self.cleanup
    end

    def self.cleanup_associations
    end

    def self.cleanup_nonces
    end

    protected

    def resolve_associations(parsed_content)
      uri_list = parsed_content['uris']
      association_responses = @@store.resolve_uris(uri_list)
      return association_responses, association_responses.map{|a| a.parsed_content}
    end
  end
end
