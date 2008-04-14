class GwtClientGenerator < RubiGen::Base
  
  default_options :author => nil
  
  #attr_reader :name
  
  def initialize(runtime_args, runtime_options = {})
    super
    #usage if args.empty?
    #@name = args.shift
    extract_options
  end

  def manifest
    record do |m|
      m.directory 'clients/gwt/lib'
      m.file 'lib/gwt-cloudkit.jar', 'clients/gwt/lib/gwt-cloudkit.jar'
      m.file 'lib/gwt-rest.jar', 'clients/gwt/lib/gwt-rest.jar'
      m.file 'lib/gwtx.jar', 'clients/gwt/lib/gwtx.jar'
      m.directory 'clients/gwt/src/ui/client/resource'
      m.template 'UI-compile.erb', 'clients/gwt/UI-compile', :chmod => 0755
      m.template 'UI-shell.erb', 'clients/gwt/UI-shell', :chmod => 0755
      m.file 'src/ui/UI.gwt.xml', 'clients/gwt/src/ui/UI.gwt.xml'
      m.file 'src/ui/client/AppEntryPoint.java', 'clients/gwt/src/ui/client/AppEntryPoint.java'
      m.directory 'views'
      m.file 'ui.erb', 'views/ui.erb'
    end
  end
  
  # TEMP
  def gwt_home
    '/usr/local/lib/gwt-mac-1.4.61'
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