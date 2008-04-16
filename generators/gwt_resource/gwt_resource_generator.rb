class GwtResourceGenerator < RubiGen::Base
  
  default_options :author => nil
  
  attr_reader :name
  
  def initialize(runtime_args, runtime_options = {})
    super
    usage if args.empty?
    @name = args.shift
    extract_options
  end

  def manifest
    record do |m|
      m.directory 'resources'
      m.directory 'clients/gwt/src/ui/client/resource'
      m.template 'resource.erb', "resources/#{name.underscore.pluralize}.rb"
      m.migration_template 'resource_migration.erb', 'db/migrate', :migration_file_name => 'create_' + name.underscore.pluralize
      m.template 'gwt_resource.erb', "clients/gwt/src/ui/client/resource/#{name.camelize}.java"
    end
  end

  protected
    
    def banner
      <<-EOS
Creates a ...

USAGE: #{$0} #{spec.name} name
EOS
    end

    def add_options!(opts)
      # opts.separator ''
      # opts.separator 'Options:'
      # For each option below, place the default
      # at the top of the file next to "default_options"
      # opts.on("-a", "--author=\"Your Name\"", String,
      #         "Some comment about this option",
      #         "Default: none") { |options[:author]| }
      # opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
    end
    
    def extract_options
      # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
      # Templates can access these value via the attr_reader-generated methods, but not the
      # raw instance variable value.
      # @author = options[:author]
    end
end