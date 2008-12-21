require 'helper'
class FlashSessionTest < Test::Unit::TestCase

  context "A FlashSession" do

    setup do
      @flash = CloudKit::FlashSession.new
    end

    should "accept a value for a key" do
      @flash['greeting'] = 'hello'
      assert_equal 'hello', @flash['greeting']
    end

    should "erase a key/value pair after access" do
      @flash['greeting'] = 'hello'
      x = @flash['greeting']
      assert_nil @flash['greeting']
    end

  end
end
