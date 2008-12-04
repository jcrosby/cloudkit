require 'helper'
class UserStoreTest < Test::Unit::TestCase
  context "A UserStore" do
    should "know its version" do
      store = CloudKit::UserStore.new
      assert_equal 1, store.version
    end
  end
end
