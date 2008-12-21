module CloudKit
  
  # An ExtractionView observes a resource collection and extracts specified
  # elements for querying.
  class ExtractionView
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
    end

    # Map the provided data into a collection for querying.
    def map(db, collection, uri, data)
      if @observe == collection
        elements = @extract.inject({}) do |e, field|
          e.merge(field.to_s => data[field.to_s])
        end
        elements.merge!('uri' => uri)
        db.transaction do
          db[@name].filter(:uri => uri).delete
          db[@name].insert(elements)
        end
      end
    end

    # Remove the data with the specified URI from the view
    def unmap(db, type, uri)
      if @observe == type
        db[@name].filter(:uri => uri).delete
      end
    end

    # Initialize the storage for this view
    def initialize_storage(db)
      extractions = @extract
      db.create_table @name do
        extractions.each do |field|
          text field
        end
        primary_key :id
        varchar     :uri
      end unless db.table_exists?(@name)
    end
  end
end
