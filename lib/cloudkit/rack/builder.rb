module Rack #:nodoc:
  class Builder #:nodoc:
    alias_method :cloudkit_to_app, :to_app

    def to_app
      default_app = lambda do |env|
        if (env['PATH_INFO'] == '/')
          [200, {'Content-Type' => 'text/html'}, [welcome]]
        else
          [404, {}, []]
        end
      end
      @ins << default_app if @last_cloudkit_id == @ins.last.object_id
      cloudkit_to_app
    end

    def contain(*args)
      @ins << lambda do |app|
        Rack::Session::Pool.new(
          CloudKit::OAuthFilter.new(
            CloudKit::OpenIDFilter.new(
              CloudKit::Service.new(app, :collections => args.to_a))))
      end
      @last_cloudkit_id = @ins.last.object_id
    end

    def expose(*args)
      @ins << lambda do |app|
        CloudKit::Service.new(app, :collections => args.to_a)
      end
      @last_cloudkit_id = @ins.last.object_id
    end

    def welcome
doc = <<HTML
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <title>CloudKit</title>
</head>
<body>
<h1>CloudKit</h1>
</body>
</html>
HTML
    end
  end
end
