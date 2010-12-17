require 'spec_helper'

describe "A FlashSession" do

  before do
    @flash = CloudKit::FlashSession.new
  end

  it "should accept a value for a key" do
    @flash['greeting'] = 'hello'
    @flash['greeting'].should == 'hello'
  end

  it "should erase a key/value pair after access" do
    @flash['greeting'] = 'hello'
    x = @flash['greeting']
    @flash['greeting'].should be_nil
  end

end
