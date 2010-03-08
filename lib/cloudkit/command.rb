module CloudKit
  class Command
    include CloudKit::Generator

    def run(args)
      return help unless command = args.first
      case command
      when 'help'
        help
      else
        @app_name = destination_root = command
        template_root = File.join(File.expand_path(File.dirname(__FILE__)), 'templates', 'gen')
        generate_app(template_root, destination_root)
      end
    end

    def generate_app(template_root, destination_root)
      FileUtils.mkdir(destination_root)
      copy_contents(template_root, destination_root)
      Formatador.display_line("[bold]#{@app_name} was created[/]")
    end

    def help
      Formatador.display_line("CloudKit")
    end
  end
end
