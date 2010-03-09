module CloudKit
  class Command
    include CloudKit::Generator

    def run(args)
      return help unless command = args.first
      case command
      when 'run'
        run_app
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

    def run_app
      unless File.exist?('.bundle')
        Formatador.display_line("[yellow][bold]No gem bundle found.[/]")
        Formatador.display_line("[green]Bundling...[/]")
        `bundle install`
      end
      Formatador.display_line("[green][bold]Starting app...[/]")
      `rackup config.ru`
    end

    def help
      Formatador.display_line("CloudKit")
    end
  end
end
