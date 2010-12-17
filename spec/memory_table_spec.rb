require 'spec_helper'

describe "A MemoryTable" do
  before(:each) do
    @table = CloudKit::MemoryTable.new
  end

  after(:each) do
    @table.clear
  end

  it_should_behave_like "a CloudKit storage adapter"

end
