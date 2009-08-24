require File.dirname(__FILE__) + '/spec_helper'

describe "Rack::Builder" do

  it "should expose services" do
    app = Rack::Builder.new do
      expose :items, :things
      run lambda {|app| [200, {}, ['hello']]}
    end
    response = Rack::MockRequest.new(app).get('/items')
    response.status.should == 200
    documents = JSON.parse(response.body)['documents']
    documents.should == []
  end

  it "should expose services with auth using 'contain'" do
    app = Rack::Builder.new do
      contain :items, :things
      run lambda {|app| [200, {}, ['hello']]}
    end
    response = Rack::MockRequest.new(app).get('/items')
    response.status.should == 401
    response = Rack::MockRequest.new(app).get('/things')
    response.status.should == 401
    response = Rack::MockRequest.new(app).get('/')
    response.status.should == 200
    response.body.should == 'hello'
  end

  it "should insert a default app if one does not exist" do
    app = Rack::Builder.new { contain :items }
    response = Rack::MockRequest.new(app).get('/items')
    response.status.should == 401
    response = Rack::MockRequest.new(app).get('/')
    response.status.should == 200
    response.body.match('CloudKit').should_not be_nil
  end

end
