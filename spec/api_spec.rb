require 'spec_helper'


describe "CloudKit REST API" do
  context "/cloudkit-meta" do

    subject { get "/cloudkit-meta" }

    it_should_behave_like "it was successful"
    it_should_behave_like "it's response is json encoded"
    it_should_behave_like "it has uris"

    it "should return the proper list of collections" do
      CloudKit::Fixtures.collection_uris.should == json_body["uris"].sort
    end
  end

  context CloudKit::Fixtures.first_collection_uri do
    context "GET" do
      subject { get(CloudKit::Fixtures.first_collection_uri) }

      context "without any items in the collection" do

        it_should_behave_like "it was successful"
        it_should_behave_like "it's response is json encoded"
      end

      context "with items in the collection" do
        before do
          @response = post CloudKit::Fixtures.first_collection_uri, {"foo" => "bar"}.to_json
        end

        it_should_behave_like "it was successful"
        it_should_behave_like "it's response is json encoded"
        it_should_behave_like "it has uris"

        it "should have the right uris" do
          json_body["uris"].should include(JSON.parse(@response.body)["uri"])
        end
      end
    end

    context "POST" do
      subject { post(CloudKit::Fixtures.first_collection_uri, {"foo" => "bar"}.to_json) }

      it_should_behave_like "it was successful"
      it_should_behave_like "it's response is json encoded"
      it_should_behave_like "it should have the proper creation response structure"

      it "should add an item to the collection" do
        original_number_of_items = JSON.parse(get(CloudKit::Fixtures.first_collection_uri).body)["uris"].length
        subject
        new_number_of_items = JSON.parse(get(CloudKit::Fixtures.first_collection_uri).body)["uris"].length
        (new_number_of_items - original_number_of_items).should == 1
      end

    end

    context "PUT" do
      subject { put("#{CloudKit::Fixtures.first_collection_uri}/foo", {"foo" => "bar"}.to_json) }

      context "when the item does not exist" do

        it_should_behave_like "it was successful"
        it_should_behave_like "it's response is json encoded"
        it_should_behave_like "it should have the proper creation response structure"

        it "should add an item to the collection" do
          original_number_of_items = JSON.parse(get(CloudKit::Fixtures.first_collection_uri).body)["uris"].length
          subject
          new_number_of_items = JSON.parse(get(CloudKit::Fixtures.first_collection_uri).body)["uris"].length
          (new_number_of_items - original_number_of_items).should == 1
        end
      end

      context "when the item already exists" do
        before do
          @initial_response = put("#{CloudKit::Fixtures.first_collection_uri}/foo", {"foo" => "bar"}.to_json)
        end

        it_should_behave_like "it's response is json encoded"

        context "without the proper etag" do

          its(:status) { should == 400 }

          it "should have an error in the body" do
            json_body.should include("error")
          end

          it "should require and etag" do
            json_body["error"].should == "etag required"
          end

        end

        context "with the proper etag" do
          let(:etag) { JSON.parse(@initial_response.body)["etag"].gsub('"','') }

          before do
            header('If-Match',etag)
          end

          subject { put("#{CloudKit::Fixtures.first_collection_uri}/foo", {"foo" => "bazzle"}.to_json ) }

          it_should_behave_like "it was successful"
          it_should_behave_like "it's response is json encoded"
          it_should_behave_like "it should have the proper update response structure"

        end
      end

    end
  end

end
