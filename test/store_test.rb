require 'helper'
class StoreTest < Test::Unit::TestCase

  context "A CloudKit::Store" do

    should "know its version" do
      store = CloudKit::Store.new(:collections => [:items])
      assert_equal 1, store.version
    end

    should "create its storage" do
      store = CloudKit::Store.new(:collections => [:items])
      assert DataMapper::Resource.descendants.include?(CloudKit::Document)
    end

    should "create views when specified if they do not exist" do
      view = CloudKit::ExtractionView.new(
        :item_colors,
        :observe => :items,
        :extract => [:color, :saturation])
      store = CloudKit::Store.new(
        :collections => [:items],
        :views       => [view])      
      assert DataMapper::Resource.descendants.include?(CloudKit::ItemColors)
    end

    should "filter using views" do
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
      assert_equal 1, uris.size
      content = store.resolve_uris(uris).first.parsed_content
      assert_equal 'green', content['color']
    end
  end
end
