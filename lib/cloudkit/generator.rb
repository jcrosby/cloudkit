module CloudKit
  module Generator
    def copy_contents(template_root, destination_root)
      paths(template_root).each do |template_path|
        if File.directory?(template_path)
          generate_directory(template_path, destination_root)
          copy_contents(template_path, File.join(destination_root, File.basename(template_path)))
        else
          generate_file(template_path, destination_root)
        end
      end
    end

    def generate_directory(template_path, destination_root)
      FileUtils.mkdir_p(File.join(destination_root, File.basename(sub(template_path))))
    end

    def generate_file(template_path, destination_root)
      content = File.read(template_path)
      path_elements = File.split(sub(destination_root)).push(File.basename(sub(template_path)))
      File.open(File.join(path_elements), 'w+') do |file|
        file.puts(ERB.new(content).result(binding))
      end
    end

    def paths(directory)
      Dir.glob(File.join(directory, '*'), File::FNM_DOTMATCH).reject do |f|
        f.match(/\/(\.){1,2}$/)
      end
    end

    def sub(name)
      name.sub('%app_name%', @app_name)
    end
  end
end
