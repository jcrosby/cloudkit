require 'helper'
class StoreTest < Test::Unit::TestCase
  class ExposedStore < CloudKit::Store
    def db; @db; end
  end
  context "A CloudKit::Store" do
    setup do
      @store = ExposedStore.new(:collections => [:items])
    end
    teardown do
      FileUtils.rm_f('test.db')
    end
    should "know its version" do
      assert_equal 1, @store.version
    end
    should "create its storage" do
      store = ExposedStore.new(:collections => [:items])
      table = store.db.schema[:items]
      assert table
      assert table.any?{|t| t[0] == :id}
      assert table.any?{|t| t[0] == :etag}
      assert table.any?{|t| t[0] == :last_modified}
      assert table.any?{|t| t[0] == :remote_user}
      assert table.any?{|t| t[0] == :content}
      table = store.db.schema[:items_history]
      assert table
      assert table.any?{|t| t[0] == :id}
      assert table.any?{|t| t[0] == :entity_id}
      assert table.any?{|t| t[0] == :etag}
      assert table.any?{|t| t[0] == :created}
      assert table.any?{|t| t[0] == :last_modified}
      assert table.any?{|t| t[0] == :remote_user}
      assert table.any?{|t| t[0] == :content}
    end
    should "not create its storage if it already exists" do
      store = ExposedStore.new(
        :collections => [:items, :notes],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      item = JSON.generate(:id => '123', :hello => 'there')
      store.put(:items, :id => '123', :data => item)
      note = JSON.generate(:id => '456', :hello => 'dolly')
      store.put(:notes, :id => '456', :data => note)
      store.db.drop_table(:items)
      store.db.drop_table(:items_history)
      store = ExposedStore.new(
        :collections => [:items, :notes],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      result = store.get(:notes, :id => '456')
      assert_equal 200, result.status
      assert store.db.schema[:items]
      assert store.db.schema[:items_history]
    end
    should "create views when specified if they do not exist" do
      view = CloudKit::ExtractionView.new(
        :fruits,
        :observe => :items,
        :extract => [:apple, :lemon])
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [view])
      table = store.db.schema[:fruits]
      assert table
      assert table.any?{|t| t[0] == :apple}
      assert table.any?{|t| t[0] == :lemon}
      assert table.any?{|t| t[0] == :content}
      assert table.any?{|t| t[0] == :entity_id}
    end
    should "not create views that already exist" do
      fruit_view = CloudKit::ExtractionView.new(
        :fruits,
        :observe => :items,
        :extract => [:apple])
      vegetable_view = CloudKit::ExtractionView.new(
        :vegetables,
        :observe => :items,
        :extract => [:bacon])
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [fruit_view, vegetable_view],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      json = JSON.generate(:id => '123', :apple => 'green')
      store.put(:items, :id => '123', :data => json)
      store.db.drop_table(:vegetables)
      store = ExposedStore.new(
        :collections => [:items],
        :views       => [fruit_view, vegetable_view],
        :adapter     => CloudKit::SQLAdapter.new('sqlite://test.db'))
      assert store.db.schema[:fruits]
      assert store.db.schema[:vegetables]
      result = store.get(:fruits, :apple => 'green')
      assert_equal 200, result.status
      assert_equal 1, result.parsed_content['documents'].size
    end
    context "on get" do
      setup do
        json = JSON.generate(
          :id    => 'abc',
          :hello => 'there')
        @store.put(:items, :id => 'abc', :data => json)
        @result = @store.get(:items, :id => 'abc')
      end
      should "return a result for existing items" do
        assert @result
      end
      should "return a 200 status code if successful" do
        assert_equal 200, @result.status
      end
      should "return a 404 if not successful" do
        result = @store.get(:items, :id => 'xyz')
        assert_equal 404, result.status
      end
      should "return the content type as metadata" do
        assert_equal 'application/json', @result['Content-Type']
      end
      should "return an etag that is a hash of the json content as metadata" do
        obj = @result.parsed_content
        obj.delete('etag')
        digest = MD5::md5(obj.to_s).hexdigest
        assert_equal digest, @result['Etag']
      end
      should "return the last modified date as metadata" do
        assert @result['Last-Modified']
      end
      should "return the id" do
        assert_equal 'abc', @result.parsed_content['id']
      end
      should "get specific document versions" do
        original_etag = @result['Etag']
        json = JSON.generate(
          :id    => 'abc',
          :hello => 'dolly',
          :etag  => original_etag)
        update_result = @store.put(:items, :id => 'abc', :data => json)
        result = @store.get(:items, :id => 'abc', :if_match => original_etag)
        assert_equal 'there', result.parsed_content['hello']
      end
      should "get the current document conditionally" do
        result = @store.get(
          :items, :id => 'abc', :if_none_match => @result['Etag'])
        assert_equal 304, result.status
        assert_equal '', result.content
      end
      should "not accept unknown collections" do
        result = @store.get(:x, :id => 'abc')
        assert_equal 400, result.status
      end
      context "with no id" do
        setup do
          json = JSON.generate(
            :id    => 'xyz',
            :hello => 'dolly')
          @store.put(:items, :id => 'xyz', :data => json)
          @list_result = @store.get(:items)
          @documents = @list_result.parsed_content['documents']
          @empty_store = ExposedStore.new(:collections => [:notes])
          @empty_result = @empty_store.get(:notes)
          @empty_documents = @empty_result.parsed_content['documents']
        end
        should "return a 200 status" do
          assert_equal 200, @list_result.status
          assert_equal 200, @empty_result.status
        end
        should "return a list of items" do
          assert @documents.any?{|d| d['id'] == 'abc'}
          assert @documents.any?{|d| d['id'] == 'xyz'}
          assert_equal 2, @documents.size
        end
        should "return an empty list if none are found" do
          assert_equal [], @empty_result.parsed_content['documents']
        end
        should "filter using keys" do
          result = @store.get(:items, :if_match => @documents[0]['etag'])
          documents = result.parsed_content['documents']
          assert_equal 1, documents.size
        end
        context "specifying a view" do
          should "filter using the view" do
            view = CloudKit::ExtractionView.new(
              :fruits,
              :observe => :items,
              :extract => [:apple, :lemon])
            store = ExposedStore.new(
              :collections => [:items],
              :views       => [view])
            json = JSON.generate(:id => '123', :apple => 'green')
            store.put(:items, :id => '123', :data => json)
            json = JSON.generate(:id => '456', :apple => 'red')
            store.put(:items, :id => '456', :data => json)
            result = store.get(:fruits, :apple => 'green')
            documents = result.parsed_content['documents']
            assert_equal 1, documents.size
            assert 'green', documents.first['apple']
          end
        end
      end
    end
    context "on put" do
      setup do
        json = JSON.generate(:id => 'abc123', :hello => 'there')
        @result = @store.put(:items, :id => 'abc123', :data => json)
      end
      should "return a result" do
        assert @result
      end
      should "return a 200 status code for items that already exist" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => @result['Etag'])
        result = @store.put(
          :items, :id => 'abc123', :if_match => @result['Etag'], :data => json)
        assert_equal 200, result.status
      end
      should "return a 201 status code for new items" do
        assert_equal 201, @result.status
      end
      should "return a 422 status code if parsing fails" do
        result = @store.put(
          :items, :id => 'abc123', :if_match => @result['Etag'], :data => 'hello')
        assert_equal 422, result.status
      end
      should "return the content type as metadata" do
        assert_equal 'application/json', @result['Content-Type']
      end
      should "return an etag that is a hash of the json content as metadata" do
        result = @store.get(:items, :id => 'abc123')
        obj = result.parsed_content
        obj.delete('etag')
        digest = MD5::md5(obj.to_s).hexdigest
        assert_equal digest, @result['Etag']
      end
      should "create documents with the specified id if they do not exist" do
        result = @store.get(:items, :id => 'abc123')
        assert_equal 200, result.status
      end
      should "update existing documents if the id exists" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => @result['Etag'])
        @store.put(
          :items, :id => 'abc123', :if_match => @result['Etag'], :data => json)
        result = @store.get(:items, :id => 'abc123')
        assert_equal 'dolly', result.parsed_content['hello']
      end
      should "return a 412 if the given etag doesn't match the current etag" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => 2)
        result = @store.put(:items, :id => 'abc123', :if_match => 2, :data => json)
        assert_equal 412, result.status
      end
      should "reject if_none_match" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => @result['Etag'])
        result = @store.put(
          :items,
          :id            => 'abc123',
          :if_match      => @result['Etag'],
          :if_none_match => 'x',
          :data          => json)
        assert_equal 412, result.status
      end
      should "require the id" do
        json = JSON.generate(
          :hello => 'dolly',
          :etag  => @result['Etag'])
        result = @store.put(:items, :if_match => @result['Etag'], :data => json)
        assert_equal 400, result.status
      end
      should "require the id parameter match the embedded id in the content" do
        json = JSON.generate(
          :id    => 'abcx',
          :hello => 'dolly', 
          :etag  => @result['Etag'])
        result = @store.put(
          :items, :id => 'abc123', :if_match => @result['Etag'], :data => json)
        assert_equal 400, result.status
      end
      should "return the id" do
        assert @result.parsed_content['id']
      end
      should "return the last modified date as metadata" do
        assert @result['Last-Modified']
      end
      should "require an etag for existing records" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly')
        result = @store.put(:items, :id => 'abc123', :data => json)
        assert_equal 400, result.status
        result = @store.get(:items, :id => 'abc123')
        assert_not_equal 'dolly', result.parsed_content['hello']
      end
      should "require the etag matches the embedded etag in the content for updates" do
        json = JSON.generate(
          :id => 'abc123',
          :etag => @result['Etag'],
          :hello => 'dolly')
        result = @store.put(
          :items, :id => 'abc123', :if_match => 'no', :data => json)
        assert_equal 400, result.status
      end
      should "version document updates" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => @result['Etag'])
        result = @store.put(:items, :id => 'abc123', :data => json)
        assert_not_equal @result['Etag'], result['Etag']
      end
      should "retain version history" do
        original_etag = @result['Etag']
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'dolly',
          :etag  => original_etag)
        update_result = @store.put(:items, :id => 'abc123', :data => json)
        result = @store.get(:items, :id => 'abc123', :if_match => original_etag)
        assert_equal 'there', result.parsed_content['hello']
      end
      should "not accept unknown collections" do
        json = JSON.generate(
          :id    => 'x',
          :hello => 'dolly')
        result = @store.put(:z, :id => 'x', :data => json)
        assert_equal 400, result.status
      end
      should "update its views" do
        view = CloudKit::ExtractionView.new(
          :fruits,
          :observe => :items,
          :extract => [:apple, :lemon])
        store = ExposedStore.new(
          :collections => [:items],
          :views       => [view])
        json = JSON.generate(:id => '123', :apple => 'green')
        store.put(:items, :id => '123', :data => json)
        json = JSON.generate(:id => '123', :apple => 'red')
        store.put(:items, :id => '123', :data => json)
        result = store.get(:fruits, :apple => 'green')
        documents = result.parsed_content['documents']
        assert_equal 1, documents.size
        assert 'red', documents.first['apple']
      end  
    end
    context "on post" do
      setup do
        json = JSON.generate(:hello => 'there')
        @result = @store.post(:items, :data => json)
      end
      should "create documents" do
        result = @store.get(:items, :id => @result.parsed_content['id'])
        assert_equal 200, result.status
      end
      should "return a result" do
        assert @result
      end
      should "return a 201 status code if successful" do
        assert_equal 201, @result.status
      end
      should "return a 422 status code if parsing fails" do
        result = @store.post(:items, :data => 'hello')
        assert_equal 422, result.status
      end
      should "return the content type as metadata" do
        assert_equal 'application/json', @result['Content-Type']
      end
      should "return an etag that is a hash of the json content as metadata" do
        result = @store.get(:items, :id => @result.parsed_content['id'])
        obj = result.parsed_content
        obj.delete('etag')
        digest = MD5::md5(obj.to_s).hexdigest
        assert_equal digest, @result['Etag']
      end
      should "return the last modified date as metadata" do
        assert @result['Last-Modified']
      end
      should "return the id" do
        assert @result.parsed_content['id']
      end
      should "ignore a submitted id" do
        json = JSON.generate(
          :id    => 'abc',
          :hello => 'there')
        result = @store.post(:items, :data => json)
        test = @store.get(:items, :id => result.parsed_content['id'])
        assert_equal 200, test.status
        assert_equal 'there', test.parsed_content['hello']
      end
      should "ignore a submitted etag" do
        json = JSON.generate(
          :hello => 'there',
          :etag  => 'hi')
        result = @store.post(:items, :data => json)
        test = @store.get(:items, :id => result.parsed_content['id'])
        assert_equal 200, test.status
        assert_equal 'there', test.parsed_content['hello']
        assert_not_equal 'hi', test.parsed_content['etag']
      end
      should "not accept unknown collections" do
        json = JSON.generate(:hello => 'there')
        result = @store.post(:x, :data => json)
        assert_equal 400, result.status
      end
      should "reject if_none_match" do
        json = JSON.generate(:id => 'a', :hello => 'hi')
        result = @store.post(
          :items,
          :id            => 'a',
          :if_none_match => 'x',
          :data          => json)
        assert_equal 412, result.status
      end
      should "insert into its views" do
        view = CloudKit::ExtractionView.new(
          :fruits,
          :observe => :items,
          :extract => [:apple, :lemon])
        store = ExposedStore.new(
          :collections => [:items],
          :views       => [view])
        json = JSON.generate(:id => '123', :apple => 'green')
        store.put(:items, :id => '123', :data => json)
        json = JSON.generate(:id => '123', :apple => 'red')
        store.put(:items, :id => '123', :data => json)
        result = store.get(:fruits, :apple => 'green')
        documents = result.parsed_content['documents']
        assert_equal 1, documents.size
        assert 'green', documents.first['apple']
      end
    end
    context "on delete" do
      setup do
        json = JSON.generate(
          :id    => 'abc',
          :hello => 'there')
        @put_result = @store.put(:items, :id => 'abc', :data => json)
        @etag = @put_result['Etag']
        @result = @store.delete(:items, :id => 'abc', :if_match => @etag)
      end
      should "delete documents" do
        result = @store.get(:items, :id => 'abc')
        assert_equal 410, result.status
      end
      should "return a 200 status code if successful" do
        assert_equal 200, @result.status
      end
      should "require an id" do
        result = @store.delete(:items, :if_match => @etag)
        assert_equal 400, result.status
      end
      should "require an etag" do
        result = @store.delete(:items, :id => 'abc')
        assert_equal 400, result.status
      end
      should "return a 404 status code for items that have never existed" do
        result = @store.delete(:items, :id => 'xyz', :if_match => @etag)
        assert_equal 404, result.status
      end
      should "require an etag matching the current version" do
        json = JSON.generate(
          :id    => 'abc123',
          :hello => 'there')
        put_result = @store.put(:items, :id => 'abc123', :data => json)
        result = @store.delete(:items, :id => 'abc123', :if_match => 'not_current')
        assert_equal 412, result.status
      end
      should "retain version history for deleted documents" do
        result = @store.get(:items, :id => 'abc', :if_match => @etag)
        assert_equal 200, result.status
      end
      should "not accept unknown collections" do
        result = @store.delete(:x, :id => 'abc', :if_match => @etag)
        assert_equal 400, result.status
      end
      should "reject if_none_match" do
        json = JSON.generate(
          :id    => 'a',
          :hello => 'there')
        put_result = @store.put(:items, :id => 'a', :data => json)
        etag = put_result['Etag']
        result = @store.delete(
          :items,
          :id            => 'a',
          :if_match      => @etag,
          :if_none_match => 'x')
      end
      should "remove records from its views" do
        view = CloudKit::ExtractionView.new(
          :fruits,
          :observe => :items,
          :extract => [:apple, :lemon])
        store = ExposedStore.new(
          :collections => [:items],
          :views       => [view])
        json = JSON.generate(:id => '123', :apple => 'green')
        result = store.put(:items, :id => '123', :data => json)
        store.delete(:items, :id => '123', :if_match => result['Etag'])
        result = store.get(:fruits, :apple => 'green')
        documents = result.parsed_content['documents']
        assert_equal [], result.parsed_content['documents']
      end
    end
  end
end
