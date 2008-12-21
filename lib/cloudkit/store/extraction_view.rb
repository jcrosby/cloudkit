module CloudKit
  class ExtractionView
    attr_accessor :name, :observe, :extract

    def initialize(name, options)
      @name    = name
      @observe = options[:observe]
      @extract = options[:extract]
    end

    def map(db, type, uri, data)
      if @observe == type
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

    def unmap(db, type, uri)
      if @observe == type
        db[@name].filter(:uri => uri).delete
      end
    end

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
