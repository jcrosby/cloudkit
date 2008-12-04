require 'helper'
class OAuthStoreTest < Test::Unit::TestCase
  context "An OAuthStore" do
    should "know its version" do
      store = CloudKit::UserStore.new
      assert_equal 1, store.version
    end
  end
end
