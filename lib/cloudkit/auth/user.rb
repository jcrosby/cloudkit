module CloudKit
  module Auth
    class User < ActiveRecord::Base
      has_many :action_items
      validates_presence_of   :identity_url
      validates_uniqueness_of :identity_url, :case_sensitive => false, :allow_nil => false
      before_save :generate_salt

      has_many :client_applications
      has_many :tokens, :class_name => "OauthToken", :order => "authorized_at desc", :include => [:client_application]

      def self.encrypt(data, salt)
        Digest::SHA1.hexdigest("--#{salt}--#{data}--")
      end

      def encrypt(data)
        self.class.encrypt(data, salt)
      end

      def remember_token?
        remember_token_expires_at && Time.now.utc < remember_token_expires_at 
      end

      def remember_me
        remember_me_for 2.weeks
      end

      def remember_me_for(time)
        remember_me_until time.from_now.utc
      end

      def remember_me_until(time)
        self.remember_token_expires_at = time
        self.remember_token = encrypt("#{self.identity_url}--#{remember_token_expires_at}")
        save(false)
      end

      def forget_me
        self.remember_token_expires_at = nil
        self.remember_token = nil
        save(false)
      end

      protected

      def generate_salt
        self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{identity_url}--") if new_record?
      end
    end
  end
end