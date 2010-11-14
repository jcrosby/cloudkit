require File.dirname(__FILE__) + '/spec_helper'

describe "A MongoStore" do
  before(:each) do
    @table = CloudKit::MongoStore.new
  end

  after(:each) do
    @table.clear
  end

  it_should_behave_like "a CloudKit storage adapter"

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

