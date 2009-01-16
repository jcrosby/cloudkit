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
    
    should "re-key false and nil values" do
      x = {:a => false, :b => nil}
      x.rekey!(:b, :c)
      assert x == {:a => false, :c => nil}
      x.rekey!(:d, :b)
      assert x == {:a => false, :c => nil}
    end

    should "merge conditionally" do
      x = {:a => 1}
      y = {:b => 2}
      x.filter_merge!(:c => y[:c])
      assert x == {:a => 1}
      x.filter_merge!(:c => y[:b])
      assert x == {:a => 1, :c => 2}
      x = {}.filter_merge!(:a => 1)
      assert x == {:a => 1}
    end

    should "merge false values correctly" do
      x = {:a => 1}
      y = {:b => 2}
      x.filter_merge!(:c => false)
      assert x == {:a => 1, :c => false}
      x.filter_merge!(:c => y[:b])
      assert x == {:a => 1, :c => 2}
      x = {}.filter_merge!(:a => false)
      assert x == {:a => false}
    end

    should "exclude pairs using a single key" do
      x = {:a => 1, :b => 2}
      y = x.excluding(:b)
      assert y == {:a => 1}
    end

    should "exclude pairs using a list of keys" do
      x = {:a => 1, :b => 2, :c => 3}
      y = x.excluding(:b, :c)
      assert y == {:a => 1}
    end
  end

  context "An Array" do

    should "exclude elements" do
      x = [0, 1, 2, 3]
      y = x.excluding(1, 3)
      assert_equal [0, 2], y
    end
  end

  context "An Object" do

    should "try" do
      x = {:a => 'a'}
      result = x[:a].try(:upcase)
      assert_equal 'A', result
      assert_nothing_raised {x[:b].try(:upcase)}
    end
  end

end
