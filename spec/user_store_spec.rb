require 'spec_helper'

describe "A UserStore" do

  it "should know its version" do
    store = CloudKit::UserStore.new
    store.version.should == 1
  end

end
