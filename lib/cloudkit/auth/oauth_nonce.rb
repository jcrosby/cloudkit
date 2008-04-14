module CloudKit
  module Auth
    class OauthNonce < ActiveRecord::Base
      validates_presence_of :nonce, :timestamp
      validates_uniqueness_of :nonce, :scope => :timestamp

      def self.remember(nonce,timestamp)
        oauth_nonce = OauthNonce.create(:nonce => nonce, :timestamp => timestamp)
        return false if oauth_nonce.new_record?
        oauth_nonce
      end
    end
  end
end
