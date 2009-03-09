require File.dirname(__FILE__) + '/spec_helper'

describe "An OpenIDStore" do

  before(:each) do
    CloudKit.setup_storage_adapter unless CloudKit.storage_adapter
    @store = CloudKit::OpenIDStore.new
    @server = 'http://openid.claimid.com/server'
    @handle = "{HMAC-SHA1}{736kwv3j}{wbhwEK==}"
    @secret = "\350\068\753\436\567\8327\232\241\025\254\3117&\016\031\355#sV"
    @issued = Time.now
    @lifetime = 120960
    @type = "HMAC-SHA1"
    @association = OpenID::Association.new(@handle, @secret, @issued, @lifetime, @type)
    @store.store_association(@server, @association)
    @result = CloudKit::Resource.all.first.parsed_json
  end
  
  after(:each) do
    CloudKit.storage_adapter.clear
  end

  it "should know its version" do
    @store.version.should == 1
  end

  describe "when storing an association" do

    it "should base64 encode the handle" do
      @result['handle'].should == Base64.encode64(@handle)
    end

    it "should base64 encode the secret" do
      @result['secret'].should == Base64.encode64(@secret)
    end

    it "should convert the issue time to an integer" do
      @result['issued'].should == @issued.to_i
    end

    it "should store the lifetime as given" do
      @result['lifetime'].should == @lifetime
    end

    it "should store the association type as given" do
      @result['assoc_type'].should == @type
    end

    it "should remove previous associations with the given server_url and association handle" do
      association = OpenID::Association.new(@handle, @secret, @issued, @lifetime, @type)
      @store.store_association(@server, association)
      associations = CloudKit::Resource.current(
        :collection_reference => "/cloudkit_openid_associations")
      associations.size.should == 1
      result = associations.first.parsed_json
      result['secret'].should == Base64.encode64(@secret)
    end
  end

  describe "when removing an association" do

    it "should succeed" do
      @store.remove_association(@server, @association.handle)
      associations = CloudKit::Resource.current(
        :collection_reference => "/cloudkit_openid_associations")
      associations.size.should == 0
    end
  end

  describe "when finding an association" do

    it "should return the correct object" do
      association = @store.get_association(@server, @association.handle)
      association.should == @association
    end
  end

  describe "when using a nonce" do

    before(:each) do
      @time = Time.now.to_i
      @salt = 'salt'
      @store.use_nonce(@server, @time, @salt)
    end

    it "should store the nonce" do
      nonce = CloudKit::Resource.first(
        :collection_reference => "/cloudkit_openid_nonces",
        :deleted              => false)
      nonce.should_not be_nil
    end

    it "should reject the nonce if it has already been used" do
      @store.use_nonce(@server, @time, @salt).should_not be_nil
      nonces = CloudKit::Resource.all(
        :collection_reference => "/cloudkit_openid_nonces",
        :deleted              => false)
      nonces.size.should == 1
    end
  end
end
