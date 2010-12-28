module CloudKit
  module Fixtures
    class << self
      def collections
        [:foo]
      end

      def collection_uris
        collections.map { |collection| "/#{collection}" }.sort
      end

      def first_collection_uri
        collection_uris.first
      end
    end
  end
end
