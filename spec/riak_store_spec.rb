require 'spec_helper'

describe "A RiakStore" do
  before(:each) do
    @table = CloudKit::RiakStore.new
  end

  after(:each) do
    @table.clear
  end

  it_should_behave_like "a CloudKit storage adapter"

end
