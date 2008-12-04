require 'helper'
class RackBuilderTest < Test::Unit::TestCase
  context "Rack::Builder" do
    should "expose services" do
      app = Rack::Builder.new do
        expose :items, :things
        run lambda {|app| [200, {}, ['hello']]}
      end
      response = Rack::MockRequest.new(app).get('/items')
      assert_equal 200, response.status
      documents = JSON.parse(response.body)['documents']
      assert_equal [], documents
    end
    should "expose services with auth using 'contain'" do
      app = Rack::Builder.new do
        contain :items, :things
        run lambda {|app| [200, {}, ['hello']]}
      end
      response = Rack::MockRequest.new(app).get('/items')
      assert_equal 401, response.status
      response = Rack::MockRequest.new(app).get('/things')
      assert_equal 401, response.status
      response = Rack::MockRequest.new(app).get('/')
      assert_equal 200, response.status
      assert_equal 'hello', response.body
    end
    should "insert a default app if one does not exist" do
      app = Rack::Builder.new { contain :items }
      response = Rack::MockRequest.new(app).get('/items')
      assert_equal 401, response.status
      response = Rack::MockRequest.new(app).get('/')
      assert_equal 200, response.status
      assert response.body.match('CloudKit')
    end
  end
end
