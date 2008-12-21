require 'helper'
class UtilTest < Test::Unit::TestCase
  include CloudKit::Util

  context "CloudKit::Util" do

    should "create routers" do
      router = r(:get, '/path')
      assert_equal Rack::Router, router.class
    end

  end
end
