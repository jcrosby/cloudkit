class AirClientGenerator < RubiGen::Base
  
  def initialize(runtime_args, runtime_options = {})
    super
    extract_options
  end

  def manifest
    record do |m|
      m.directory 'clients/air/build'
      m.directory 'public/air'
      m.template 'app.erb', 'clients/air/app.html'
      m.template 'app.xml.erb', 'clients/air/app.xml'
      m.file 'AIRAliases.js', 'clients/air/AIRAliases.js'
      m.file 'servicemonitor.swf', 'clients/air/servicemonitor.swf'
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
    end
    
    def extract_options
    end
end