require File.dirname(__FILE__) + '/spec_helper'

describe "A Hash" do

  it "should re-key an entry if it exists" do
    x = {:a => 1, :b => 2}
    x.rekey!(:b, :c)
    x.should == {:a => 1, :c => 2}
    x.rekey!(:d, :b)
    x.should == {:a => 1, :c => 2}
  end

  it "should re-key false and nil values" do
    x = {:a => false, :b => nil}
    x.rekey!(:b, :c)
    x.should == {:a => false, :c => nil}
    x.rekey!(:d, :b)
    x.should == {:a => false, :c => nil}
  end

  it "should merge conditionally" do
    x = {:a => 1}
    y = {:b => 2}
    x.filter_merge!(:c => y[:c])
    x.should == {:a => 1}
    x.filter_merge!(:c => y[:b])
    x.should == {:a => 1, :c => 2}
    x = {}.filter_merge!(:a => 1)
    x.should == {:a => 1}
  end

  it "should merge false values correctly" do
    x = {:a => 1}
    y = {:b => 2}
    x.filter_merge!(:c => false)
    x.should == {:a => 1, :c => false}
    x.filter_merge!(:c => y[:b])
    x.should == {:a => 1, :c => 2}
    x = {}.filter_merge!(:a => false)
    x.should == {:a => false}
  end

  it "should exclude pairs using a single key" do
    x = {:a => 1, :b => 2}
    y = x.excluding(:b)
    y.should == {:a => 1}
  end

  it "should exclude pairs using a list of keys" do
    x = {:a => 1, :b => 2, :c => 3}
    y = x.excluding(:b, :c)
    y.should == {:a => 1}
  end

end

describe "An Array" do

  it "should exclude elements" do
    x = [0, 1, 2, 3]
    y = x.excluding(1, 3)
    y.should == [0, 2]
  end

end

describe "An Object" do

  it "should try" do
    x = {:a => 'a'}
    result = x[:a].try(:upcase)
    result.should == 'A'
    lambda { x[:b].try(:upcase) }.should_not raise_error
  end

end
