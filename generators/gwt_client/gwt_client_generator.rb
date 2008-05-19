class GwtClientGenerator < RubiGen::Base

  default_options :gwt_home => nil
  
  def initialize(runtime_args, runtime_options = {})
    super
    extract_options
  end

  def manifest
    record do |m|
      m.directory 'clients/gwt/lib'
      m.file 'lib/gwt-cloudkit.jar', 'clients/gwt/lib/gwt-cloudkit.jar'
      m.file 'lib/gwt-rest.jar', 'clients/gwt/lib/gwt-rest.jar'
      m.file 'lib/gwtx.jar', 'clients/gwt/lib/gwtx.jar'
      m.file 'lib/gwittir-core-0.3.jar', 'clients/gwt/lib/gwittir-core-0.3.jar'
      m.directory 'clients/gwt/src/ui/client/migration'
      m.directory 'clients/gwt/src/ui/client/resource'
      m.template 'UI-compile.erb', 'clients/gwt/UI-compile', :chmod => 0755
      m.template 'UI-shell.erb', 'clients/gwt/UI-shell', :chmod => 0755
      m.file 'src/ui/UI.gwt.xml', 'clients/gwt/src/ui/UI.gwt.xml'
      m.file 'src/ui/client/AppEntryPoint.java', 'clients/gwt/src/ui/client/AppEntryPoint.java'
      m.directory 'views'
      m.file 'ui.erb', 'views/ui.erb'
      m.readme 'README'
    end
  end
  
  def gwt_dev_platform
    if RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince/
      'win'
    elsif RUBY_PLATFORM =~ /darwin/
      'mac'
    else
      'linux' # TODO map out possibilities and allow user to override
    end
  end

  protected
    def banner
      <<-EOS
Creates a ...

USAGE: #{$0} #{spec.name}
EOS
    end

    def add_options!(opts)
      opts.on("-g", "--gwt-home=\"/path/to/gwt\"", String, "Path to your root GWT directory", "Default: /usr/local/lib/gwt") { |options[:gwt_home]| }
    end
    
    def extract_options
      @gwt_home = options[:gwt_home]
    end
end