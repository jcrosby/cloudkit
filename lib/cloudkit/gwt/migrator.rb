module CloudKit
  module GWT
    class Migrator
      def initialize(connection, project_root)
        @connection = connection
        @project_root = project_root
        @gwt_root = File.join(project_root, 'clients', 'gwt')
        @resource_root = File.join(@gwt_root, 'src', 'ui', 'client', 'resource')
      end
    
      def migrate
        @connection.tables.sort.each do |table|
          generate_gwt_model_if_defined(table) unless table == 'schema_info'
        end
      end

      def generate_gwt_model_if_defined(table)
        if File.exists?(@gwt_root)
          Dir.foreach(@resource_root) do |stub|
            create_model(table) if ((stub.first != '.') && (stub == table.camelize.singularize + '.java'))
          end
        end
      end

      def create_model(table)
        columns = @connection.columns(table)
        gwt_resource_name = table.camelize.singularize

        if @connection.respond_to?(:pk_and_sequence_for)
          pk, pk_seq = @connection.pk_and_sequence_for(table)
        end
        pk ||= 'id'
  
        properties = {}
  
        if columns.detect { |c| c.name == pk }
          properties['id'] = 'int'
        end

        column_specs = columns.map do |column|
          next if column.name == pk
          properties[java_property_name(column)] = java_mapping(column.type)
        end
  
        template_file = open(File.join(File.dirname(__FILE__), 'templates', 'resource_base_template.erb'))
        template = ERB.new(template_file.read, nil, '-')
  
        open(File.join(@resource_root, table.camelize.singularize + 'Base.java'), 'w') { |f| f << template.result(binding) }
      end

      def java_property_name(column)
        s = column.name.inspect.to_s.gsub('"', '').camelize
        return s.sub(s.first, s.first.downcase)
      end

      def java_mapping(column_type)
        case column_type.to_s
          when 'string'
            'String'
          when 'text'
            'String'
          when 'integer'
            'int'
          when 'float'
            'double'
          when 'decimal'
            'double'
          when 'datetime'
            'Date'
          when 'timestamp'
            'Date'
          when 'time'
            'Date'
          when 'date'
            'DateOnly' # Parsing of a date-only format in GWT needs different treatment than other formats
          when 'binary'
            'String'
          when 'boolean'
            'boolean'
        end
      end
    end
  end
end