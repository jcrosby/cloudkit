class CloudkitGenerator < RubiGen::Base
  
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'],
                              Config::CONFIG['ruby_install_name'])
  
  default_options :author => nil
  
  attr_reader :name
  
  def initialize(runtime_args, runtime_options = {})
    super
    usage if args.empty?
    @destination_root = File.expand_path(args.shift)
    @name = base_name
    extract_options
  end

  def manifest
    record do |m|
      # Ensure appropriate folder(s) exists
      m.directory ''
      BASEDIRS.each { |path| m.directory path }

      m.directory 'clients'
      m.file 'app.rb', 'app.rb'
      m.file 'config.ru', 'config.ru'
      m.directory 'db/migrate'
      m.directory 'public/js'
      m.directory 'public/css'
      m.directory 'public/images'
      m.directory 'resources'
      m.file 'resources.rb', 'resources.rb'
      m.directory 'views'
      m.file 'Rakefile', 'Rakefile'
      m.file 'README', 'README'
      m.template 'db/config.erb', 'db/config.yml'
      m.file 'db/migrate/001_create_schema.rb', 'db/migrate/001_create_schema.rb'
      m.file 'views/layout.erb', 'views/layout.erb'
      m.file 'views/new_session.erb', 'views/new_session.erb'
      m.file 'views/oauth_auth.erb', 'views/oauth_auth.erb'
      m.file 'views/oauth_auth_failure.erb', 'views/oauth_auth_failure.erb'
      m.file 'views/oauth_auth_success.erb', 'views/oauth_auth_success.erb'
      m.file 'views/oauth_clients_edit.erb', 'views/oauth_clients_edit.erb'
      m.file 'views/oauth_clients_index.erb', 'views/oauth_clients_index.erb'
      m.file 'views/oauth_clients_new.erb', 'views/oauth_clients_new.erb'
      m.file 'views/oauth_clients_show.erb', 'views/oauth_clients_show.erb'
      m.file 'views/ui.erb', 'views/ui.erb'
      
      m.dependency "install_rubigen_scripts", [destination_root, 'cloudkit'], 
        :shebang => options[:shebang], :collision => :force
        
      m.readme 'POST_GENERATION_INFO'
    end
  end

  protected
    def banner
      <<-EOS
Creates a ...

USAGE: #{spec.name} name
EOS
    end

    def add_options!(opts)
      opts.separator ''
      opts.separator 'Options:'
      # For each option below, place the default
      # at the top of the file next to "default_options"
      # opts.on("-a", "--author=\"Your Name\"", String,
      #         "Some comment about this option",
      #         "Default: none") { |options[:author]| }
      opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
    end
    
    def extract_options
      # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
      # Templates can access these value via the attr_reader-generated methods, but not the
      # raw instance variable value.
      # @author = options[:author]
    end

    # Installation skeleton.  Intermediate directories are automatically
    # created so don't sweat their absence here.
    BASEDIRS = %w(
      lib
      log
      script
      test
      tmp
    )
end