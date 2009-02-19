require File.dirname(__FILE__) + '/spec_helper'

describe "A CloudKit::Store" do

  it "should know its version" do
    store = CloudKit::Store.new(:collections => [:items])
    store.version.should == 1
  end

  it "should create its storage" do
    store = CloudKit::Store.new(:collections => [:items])
    DataMapper::Resource.descendants.include?(CloudKit::Document).should be_true
  end

  it "should create views when specified if they do not exist" do
    view = CloudKit::ExtractionView.new(
      :item_colors,
      :observe => :items,
      :extract => [:color, :saturation])
    store = CloudKit::Store.new(
      :collections => [:items],
      :views       => [view])      
    DataMapper::Resource.descendants.include?(CloudKit::ItemColors).should be_true
  end

  it "should filter using views" do
    view = CloudKit::ExtractionView.new(
      :colors,
      :observe => :items,
      :extract => [:color, :saturation])
    store = CloudKit::Store.new(
      :collections => [:items],
      :views       => [view])
    json = JSON.generate(:color => 'green')
    store.put('/items/123', :json => json)
    json = JSON.generate(:color => 'red')
    store.put('/items/456', :json => json)
    result = store.get('/colors', :color => 'green')
    uris = result.parsed_content['uris']
    uris.size.should == 1
    content = store.resolve_uris(uris).first.parsed_content
    content['color'].should == 'green'
  end
end
