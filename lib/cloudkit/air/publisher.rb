module CloudKit
  module AIR
    class Publisher
      def self.publish(config)
        template_file = open(File.join(File.dirname(__FILE__), 'templates', 'version_template.erb'))
        template = ERB.new(template_file.read, nil, '-')
        open(config.directory + '/../../resources/version.rb', 'w') { |f| f << template.result(binding) }
      end
    end
  end
end