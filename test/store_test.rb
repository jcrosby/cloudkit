require 'helper'
class StoreTest < Test::Unit::TestCase

  class ExposedStore < CloudKit::Store
    def db; @db; end
  end

  context "A CloudKit::Store" do

    should "know its version" do
      store = ExposedStore.new(:collections => [:items])
      assert_equal 1, store.version
    end

    should "create its storage" do
      store = ExposedStore.new(:collections => [:items])
      table = store.db.schema[CLOUDKIT_STORE]
      assert table
      assert table.any?{|t| t[0] == :id}
      assert table.any?{|t| t[0] == :uri}
      assert table.any?{|t| t[0] == :etag}
      assert table.any?{|t| t[0] == :collection_reference}
      assert table.any?{|t| t[0] == :resource_reference}
      assert table.any?{|t| t[0] == :last_modified}
      assert table.any?{|t| t[0] == :remote_user}
      assert table.any?{|t| t[0] == :content}
      assert table.any?{|t| t[0] == :deleted}
    end

    should "create views when specified if they do not exist" do
      view = CloudKit::ExtractionView.new(
        :item_colors,
        :observe => :items,
        :extract => [:color, :saturation])
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [view])
      table = store.db.schema[:item_colors]
      assert table
      assert table.any?{|t| t[0] == :color}
      assert table.any?{|t| t[0] == :saturation}
      assert table.any?{|t| t[0] == :uri}
    end

    should "not create views that already exist" do
      color_view = CloudKit::ExtractionView.new(
        :colors,
        :observe => :items,
        :extract => [:color, :saturation])
      weight_view = CloudKit::ExtractionView.new(
        :weights,
        :observe => :items,
        :extract => [:weight])
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [color_view, weight_view],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      json = JSON.generate(:color => 'green')
      store.put('/items/123', :json => json)
      store.db.drop_table(:weights)
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [color_view, weight_view],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      assert store.db.schema[:colors]
      assert store.db.schema[:weights]
      result = store.get('/colors', :color => 'green')
      FileUtils.rm_f('test.db')
      assert_equal 200, result.status
      assert_equal 1, result.parsed_content['uris'].size
    end

    should "filter using views" do
      view = CloudKit::ExtractionView.new(
        :colors,
        :observe => :items,
        :extract => [:color, :saturation])
      store = ExposedStore.new(
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
