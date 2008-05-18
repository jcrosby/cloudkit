class AirClientGenerator < RubiGen::Base
  attr_reader :name
  default_options :app_id => nil
  
  def initialize(runtime_args, runtime_options = {})
    super
    @name = args.shift
    extract_options
    @name ||= 'AppName'
    options[:app_id] ||= "com.yourcompany.#{@name}"
  end

  def manifest
    record do |m|
      m.directory 'clients/air/build'
      m.directory 'public/air'
      m.template 'app.erb', 'clients/air/app.html'
      m.template 'app.xml.erb', 'clients/air/app.xml'
      m.file 'AIRAliases.js', 'clients/air/AIRAliases.js'
      m.file 'servicemonitor.swf', 'clients/air/servicemonitor.swf'
      m.readme 'README'
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
      opts.on("-i", "--app-id=\"com.yourcompany.AppName\"", String, "Reverse DNS-style unique ID for your app", "Default: com.yourcompany.AppName") { |options[:app_id]| }
    end
    
    def extract_options
      @app_id = options[:app_id]
    end
end