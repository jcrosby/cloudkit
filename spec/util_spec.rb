require 'spec_helper'
include CloudKit::Util

describe "CloudKit::Util" do

  it "should create routers" do
    router = r(:get, '/path')
    router.class.should == Rack::Router
  end

end
