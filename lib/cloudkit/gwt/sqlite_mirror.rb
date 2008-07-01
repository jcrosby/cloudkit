module CloudKit
  module GWT
    class SQLiteMirror
      def initialize(log_file)
        @log_file = log_file
      end
      
      def build_migrations
        migrations = []
        statements = []
        
        File.readlines(@log_file).each do |line|
          sql = line.split(/\e/)[3]
          next if (sql == nil || sql =~ /SQLException/ || sql == "\n" || sql =~ /version\(\*\)/ || sql =~ /SELECT version FROM schema_migrations/ || sql =~ /CREATE TABLE "schema_migrations"/ || sql =~ /SELECT name/)
          statements << sql.gsub(/\[(\d*|\d*;\d*)m/, '')
          ((migrations << statements) && statements = []) if statements[statements.size-1] =~ /INSERT INTO schema_migrations/
        end
        migrations
      end
      
      def mirror(gwt_root)
        return unless File.exist? gwt_root
        
        migrations = build_migrations
        
        collection_template_file = open(File.join(File.dirname(__FILE__), 'templates', 'migration_collection_template.erb'))
        collection_template = ERB.new(collection_template_file.read, nil, '-')
        
        open(gwt_root + '/src/ui/client/migration/ApplicationMigration.java', 'w') { |f| f << collection_template.result(binding) }
        
        migration_template_file = open(File.join(File.dirname(__FILE__), 'templates', 'migration_template.erb'))
        migration_template = ERB.new(migration_template_file.read, nil, '-')
        
        migrations.each_with_index do |migration, migration_count|
          open(gwt_root + "/src/ui/client/migration/Migration#{migration_count+1}.java", 'w') { |f| f << migration_template.result(binding) }
        end
      end
    end
  end
end