module CloudKit
  module AIR
    class ApplicationDescriptor
      require 'rexml/document'
      attr_reader :name, :version, :path, :directory
      
      def initialize(path)
        @path = path
        @directory = File.dirname(path)
        doc = REXML::Document.new(File.open(path, 'r').read)
        @name = REXML::XPath.first(doc, '//name').children[0]
        @version = REXML::XPath.first(doc, '//version').children[0]
      end
    end
  end
end