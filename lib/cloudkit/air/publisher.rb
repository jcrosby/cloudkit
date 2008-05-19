module CloudKit
  module AIR
    class Publisher
      def self.publish(config)
        template_file = open(File.join(File.dirname(__FILE__), 'templates', 'version_template.erb'))
        template = ERB.new(template_file.read, nil, '-')
        open(config.directory + '/../../resources/version.rb', 'w') { |f| f << template.result(binding) }
      end
      
      def self.publish_patch(config)
        new_version_parts = self.new_version_parts(config)
        new_version_parts[2] = new_version_parts[2].to_i + 1
        self.write_new_version(config, new_version_parts)
      end
      
      def self.publish_minor(config)
        new_version_parts = self.new_version_parts(config)
        new_version_parts[1] = new_version_parts[1].to_i + 1
        new_version_parts[2] = 0
        self.write_new_version(config, new_version_parts)
      end
      
      def self.publish_major(config)
        new_version_parts = self.new_version_parts(config)
        new_version_parts[0] = new_version_parts[0].to_i + 1
        new_version_parts[1] = 0
        new_version_parts[2] = 0
        self.write_new_version(config, new_version_parts)
      end
      
      def self.new_version_parts(config)
        old_content = open(config.path, 'r').read
        # old_file.close
        old_version_parts = config.version.to_s.split('.')
        new_version_parts = []
        0.upto(2) do |i|
          new_version_parts[i] = old_version_parts[i] || '0'
        end
        new_version_parts
      end
      
      def self.write_new_version(config, new_version_parts)
        old_content = open(config.path, 'r').read
        new_version = new_version_parts.join('.')
        new_content = old_content.gsub(/<version>.*<\/version>/, "<version>#{new_version}</version>")
        open(config.path, 'w') { |f| f << new_content }
      end
    end
  end
end
