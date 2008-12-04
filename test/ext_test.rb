require 'helper'
class ExtTest < Test::Unit::TestCase
  context "A Hash" do
    should "re-key an entry if it exists" do
      x = {:a => 1, :b => 2}
      x.rekey!(:b, :c)
      assert x == {:a => 1, :c => 2}
      x.rekey!(:d, :b)
      assert x == {:a => 1, :c => 2}
    end
    should "merge conditionally" do
      x = {:a => 1}
      y = {:b => 2}
      x.filter_merge!(:c => y[:c])
      assert x == {:a => 1}
      x.filter_merge!(:c => y[:b])
      assert x == {:a => 1, :c => 2}
    end
  end
  context "An Object" do
    should "try" do
      x = {:a => 'a'}
      result = x[:a].try(:upcase)
      assert_equal 'A', result
      assert_nothing_raised do
        x[:b].try(:upcase)
      end
    end
  end
end
