require File.dirname(__FILE__) + '/spec_helper'

describe "A MemoryTable" do
  before(:each) do
    @table = CloudKit::MemoryTable.new
  end

  after(:each) do
    @table.clear
  end

  it "should reject non-hash records" do
    @table['a'] = 1
    @table['a'].should be_nil
  end

  it "should reject non-string record keys" do
    @table['a'] = {:foo => 'bar'}
    @table['a'].should be_nil
  end

  it "should reject non-string record values" do
    @table['a'] = {'foo' => 1}
    @table['a'].should be_nil
  end

  it "should get and set values for table keys like a hash" do
    @table['a'] = {'foo' => 'bar'}
    @table['a'].should == {'foo' => 'bar'}
  end

  it "should clear its contents" do
    @table['a'] = {'foo' => 'bar'}
    @table['b'] = {'foo' => 'baz'}
    @table.clear
    @table['a'].should be_nil
    @table['b'].should be_nil
    @table.keys.should be_empty
  end

  it "should keep an ordered set of keys" do
    @table['b'] = {'foo' => 'bar'}
    @table['a'] = {'foo' => 'baz'}
    @table.keys.should == ['b', 'a']
  end

  it "should generate incrementing ids" do
    ids = []
    4.times { ids << @table.generate_unique_id }
    ids.should == [1, 2, 3, 4]
  end

  it "should query using a block supporting :eql comparisons" do
    # For this release, only :eql comparisons are required
    @table['a'] = {'foo' => 'bar', 'color' => 'blue'}
    @table['b'] = {'foo' => 'baz', 'color' => 'blue'}
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
    }.should == [{'foo' => 'bar', 'color' => 'blue', :pk => 'a'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'baz')
    }.should == [{'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
    @table.query { |q|
      q.add_condition('color', :eql, 'blue')
    }.should == [
      {'foo' => 'bar', 'color' => 'blue', :pk => 'a'},
      {'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
      q.add_condition('color', :eql, 'blue')
    }.should == [{'foo' => 'bar', 'color' => 'blue', :pk => 'a'}]
    @table.query { |q|
      q.add_condition('foo', :eql, 'bar')
      q.add_condition('color', :eql, 'red')
    }.should == []
  end

  it "should query without a block" do
    @table['a'] = {'foo' => 'bar', 'color' => 'blue'}
    @table['b'] = {'foo' => 'baz', 'color' => 'blue'}
    @table.query.should == [
      {'foo' => 'bar', 'color' => 'blue', :pk => 'a'},
      {'foo' => 'baz', 'color' => 'blue', :pk => 'b'}]
  end

end
