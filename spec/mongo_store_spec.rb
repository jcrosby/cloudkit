require File.dirname(__FILE__) + '/spec_helper'

describe "A MongoStore" do
  before(:each) do
    @table = CloudKit::MongoStore.new
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
    #FIXME: Does the order really matter?
    # AFAICT #keys isn't really used by anything publically except these tests.
    pending
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
    @table.query{ |q|
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

  it "should create the default indexes for a collection" do
    @table['a'] = {'foo' => 'bar' }
    @table.db['default'].index_information.keys.length.should == 6  # There are 5 default ones and then the special "_id_"
  end

  describe "when created with custom indexes" do
    before(:each) do
      # Create an ascending index on 'foo', in the background
      create_index_form_1 = [ ['foo', Mongo::ASCENDING] ], {:background => true }
      # Create an index on 'bar'
      create_index_form_2 = 'bar'
      #Create a compound index on 'foo' and 'bar', no options
      create_index_form_3 = [ [ ['foo', Mongo::ASCENDING], ['bar', Mongo::ASCENDING] ] ]
      @table = CloudKit::MongoStore.new(:custom_indexes => { 'default' => [ create_index_form_1, create_index_form_2, create_index_form_3 ] })
    end
    it "should create those indexes" do
      @table['a'] = {'foo' => 'bar'}
      @table['b'] = {'bar' => 'foo'}
      @table.db['default'].index_information.keys.length.should == 9 # 5 default + "_id_" + the 3 custom specified above
      @table.db['default'].index_information.keys.should include('foo_1')
      @table.db['default'].index_information.keys.should include('bar_1')
      @table.db['default'].index_information.keys.should include('foo_1_bar_1')
    end
  end

end

