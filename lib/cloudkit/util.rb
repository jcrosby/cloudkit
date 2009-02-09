module CloudKit
  module Util

    # Render ERB content
    def erb(request, template, headers={'Content-Type' => 'text/html'}, status=200)
      template_file = open(
        File.join(File.dirname(__FILE__),
        'templates',
        "#{template.to_s}.erb"))
      template = ERB.new(template_file.read)
      result = template.result(binding)
      Rack::Response.new(result, status, headers).finish
    end

    # Build a Rack::Router instance
    def r(method, path, params=[])
      Rack::Router.new(method, path, params)
    end

    # Remove the outer double quotes from a given string.
    def unquote(text)
      (text =~ /^\".*\"$/) ? text[1..-2] : text
    end

    def class_for(symbol)
      ::CloudKit.const_get(class_name_for(symbol))
    end

    def class_name_for(symbol)
      symbol.to_s.gsub(/^\//, '').gsub(/(?:^|_)(.)/) { $1.upcase }
    end
  end
end
