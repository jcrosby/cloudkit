module CloudKit
  class ExtractionView
    attr_accessor :name, :observe, :extract

    def initialize(name, options)
      @name = name
      @observe = options[:observe]
      @extract = options[:extract]
    end

    def map(db, type, data)
      if @observe == type
        elements = @extract.inject({}) do |e, field|
          e.merge(field.to_s => data[field.to_s])
        end
        elements.merge!(
          'entity_id' => data['id'],
          'content'   => JSON.generate(data))
        db[@name].filter(:entity_id => data['id']).delete
        db[@name].insert(elements)
      end
    end

    def unmap(db, type, id)
      if @observe == type
        db[@name].filter(:entity_id => id).delete
      end
    end

    def create_storage(db)
      extractions = @extract
      db.create_table @name do
        extractions.each do |field|
          text field
        end
        text :content
        varchar :entity_id
        index :entity_id
      end unless db.table_exists?(@name)
    end
  end
end
