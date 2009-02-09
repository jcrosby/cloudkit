require 'helper'
class OpenIDStoreTest < Test::Unit::TestCase

  context "An OpenIDStore" do

    setup do
      @store = CloudKit::OpenIDStore.new
      DataMapper.auto_migrate!
      @server = 'http://openid.claimid.com/server'
      @handle = "{HMAC-SHA1}{736kwv3j}{wbhwEK==}"
      @secret = "\350\068\753\436\567\8327\232\241\025\254\3117&\016\031\355#sV"
      @issued = Time.now
      @lifetime = 120960
      @type = "HMAC-SHA1"
      @association = OpenID::Association.new(@handle, @secret, @issued, @lifetime, @type)
      @store.store_association(@server, @association)
      @result = JSON.parse(CloudKit::Document.first.content)
    end

    should "know its version" do
      assert_equal 1, @store.version
    end

    context "when storing an association" do

      should "base64 encode the handle" do
        assert_equal Base64.encode64(@handle), @result['handle']
      end

      should "base64 encode the secret" do
        assert_equal Base64.encode64(@secret), @result['secret']
      end

      should "convert the issue time to an integer" do
        assert_equal @issued.to_i, @result['issued']
      end

      should "store the lifetime as given" do
        assert_equal @lifetime, @result['lifetime']
      end

      should "store the association type as given" do
        assert_equal @type, @result['assoc_type']
      end

      should "remove previous associations with the given server_url and association handle" do
        association = OpenID::Association.new(@handle, @secret, @issued, @lifetime, @type)
        @store.store_association(@server, association)
        associations = CloudKit::Document.all(
          :collection_reference => "/cloudkit_openid_associations",
          :deleted              => false,
          :conditions           => ["uri = resource_reference"])
        assert_equal 1, associations.size
        result = JSON.parse(associations.first.content)
        assert_equal Base64.encode64(@secret), result['secret']
      end
    end

    context "when removing an association" do

      should "succeed" do
        @store.remove_association(@server, @association.handle)
        associations = CloudKit::Document.all(
          :collection_reference => "/cloudkit_openid_associations",
          :deleted              => false,
          :conditions           => ["uri = resource_reference"])
        assert_equal 0, associations.size
      end
    end

    context "when finding an association" do

      should "return the correct object" do
        association = @store.get_association(@server, @association.handle)
        assert_equal @association, association
      end
    end

    context "when using a nonce" do

      setup do
        @time = Time.now.to_i
        @salt = 'salt'
        @store.use_nonce(@server, @time, @salt)
      end

      should "store the nonce" do
        nonce = CloudKit::Document.first(
          :collection_reference => "/cloudkit_openid_nonces",
          :deleted              => false,
          :conditions           => ["uri = resource_reference"])
        assert nonce
      end

      should "reject the nonce if it has already been used" do
        assert !@store.use_nonce(@server, @time, @salt)
        nonces = CloudKit::Document.all(
          :collection_reference => "/cloudkit_openid_nonces",
          :deleted              => false,
          :conditions           => ["uri = resource_reference"])
        assert_equal 1, nonces.size
      end
    end
  end
end
