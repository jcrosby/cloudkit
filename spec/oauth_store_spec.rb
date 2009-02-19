require File.dirname(__FILE__) + '/spec_helper'

describe "An OAuthStore" do

  it "should know its version" do
    store = CloudKit::UserStore.new
    store.version.should == 1
  end

end
