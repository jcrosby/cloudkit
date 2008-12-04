require 'helper'
class OpenIDStoreTest < Test::Unit::TestCase
  context "An OpenIDStore" do
    should "know its version" do
      store = CloudKit::UserStore.new
      assert_equal 1, store.version
    end
  end
end
