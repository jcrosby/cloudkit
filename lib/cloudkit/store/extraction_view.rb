module CloudKit

  # An ExtractionView observes a resource collection and extracts specified
  # elements for querying.
  class ExtractionView
    include CloudKit::Util
    attr_accessor :name, :observe, :extract

    # Initialize an ExtractionView.
    #
    # ==Examples
    #
    # Observe a "notes" collection and extract the titles and colors.
    #   view = ExtractionView.new(
    #     :name => :note_features,
    #     :observe => :notes,
    #     :extract => [:title, :color])
    #
    def initialize(name, options)
      @name    = name
      @observe = options[:observe]
      @extract = options[:extract]
      initialize_storage
    end

    # Map the provided data into a collection for querying.
    def map(collection, uri, data)
      if @observe == collection
        elements = @extract.inject({}) do |e, field|
          e.merge(field => data[field.to_s])
        end

        transaction = DataMapper::Transaction.new(resources)
        transaction.begin
        DataMapper.repository(:default).adapter.push_transaction(transaction)

        resources.all(:uri => uri).each {|item| item.destroy}
        resources.create(elements.merge!(:uri => uri))

        DataMapper.repository(:default).adapter.pop_transaction
        transaction.commit
      end
    end

    # Remove the data with the specified URI from the view
    def unmap(collection, uri)
      if @observe == collection
        resources.all(:uri => uri).each {|item| item.destroy}
      end
    end

    protected

    # Initialize the storage for this view
    def initialize_storage
      code = "module ::CloudKit; class #{class_name_for(@name)}; include DataMapper::Resource; property :id, Serial; property :uri, String, :length => 255, :unique => true; "
      @extract.each do |field|
        code << "property :#{field}, Text; "
      end
      code << "end; end"
      eval(code)
    end

    def resources
      @resources ||= class_for(@name)
    end
  end
end
