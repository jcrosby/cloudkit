module CloudKit
  module GWT
    class SQLiteMirror
      def initialize(log_file)
        @log_file = log_file
      end
      
      def mirror(gwt_root)
        return unless File.exist? gwt_root
        migrations = []
        statements = []
        
        File.readlines(@log_file).each do |line|
          sql = line.split(/\e/)[3]
          next if (sql == nil || sql =~ /SQLException/ || sql == "\n" || sql =~ /version\(\*\)/ || sql =~ /SELECT version FROM schema_info/ || sql =~ /CREATE TABLE schema_info/ || sql =~ /INSERT INTO schema_info/)
          statements << sql.gsub(/\[(\d*|\d*;\d*)m/, '')
          ((migrations << statements) && statements = []) if statements[statements.size-1] =~ /UPDATE schema_info SET version/
        end
        
        collection_template_file = open(File.join(File.dirname(__FILE__), 'templates', 'migration_collection_template.erb'))
        collection_template = ERB.new(collection_template_file.read, nil, '-')
        
        open(gwt_root + '/src/ui/client/migration/ApplicationMigration.java', 'w') { |f| f << collection_template.result(binding) }
        
        migration_template_file = open(File.join(File.dirname(__FILE__), 'templates', 'migration_template.erb'))
        migration_template = ERB.new(migration_template_file.read, nil, '-')
        
        migration_count = 0
        migrations.each do |migration|
          open(gwt_root + "/src/ui/client/migration/Migration#{migration_count+1}.java", 'w') { |f| f << migration_template.result(binding) }
          migration_count += 1
        end
      end
    end
  end
end