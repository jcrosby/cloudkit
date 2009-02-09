module CloudKit
  class Document
    include DataMapper::Resource

    property :id,                   Serial
    property :etag,                 String
    property :last_modified,        String
    property :uri,                  String, :length => 255, :unique => true
    property :collection_reference, String, :length => 255
    property :resource_reference,   String, :length => 255
    property :remote_user,          String, :length => 255
    property :content,              Text
    property :deleted,              Boolean, :default => false

    before :create do
      self.etag = UUID.generate
      self.last_modified = Time.now.httpdate
    end
  end
end
