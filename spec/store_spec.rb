require 'spec_helper'

describe "A CloudKit::Store" do

  it "should know its version" do
    store = CloudKit::Store.new(:collections => [:items])
    store.version.should == 1
  end

end
