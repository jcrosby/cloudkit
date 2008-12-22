module Rack #:nodoc:
  class Builder
    alias_method :cloudkit_to_app, :to_app

    # Extends Rack::Builder's to_app method to detect if the last piece of
    # middleware in the stack is a CloudKit shortcut (contain or expose), adding
    # adding a default developer page at the root and a 404 everywhere else.
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

    # Setup resource collections hosted behind OAuth and OpenID auth filters.
    #
    # ===Example
    #   contain :notes, :projects
    #
    def contain(*args)
      @ins << lambda do |app|
        Rack::Session::Pool.new(
          CloudKit::OAuthFilter.new(
            CloudKit::OpenIDFilter.new(
              CloudKit::Service.new(app, :collections => args.to_a))))
      end
      @last_cloudkit_id = @ins.last.object_id
    end

    # Setup resource collections without authentication.
    #
    # ===Example
    #   expose :notes, :projects
    #
    def expose(*args)
      @ins << lambda do |app|
        CloudKit::Service.new(app, :collections => args.to_a)
      end
      @last_cloudkit_id = @ins.last.object_id
    end

    def welcome #:nodoc:
doc = <<HTML
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <title>CloudKit via cURL</title>
  <style type="text/css">
    body {
      font-family: 'Helvetica', 'Arial', san-serif;
      font-size: 15px;
      margin: 0;
      padding: 0;
      color: #222222;
    }
    h1 {
      font-family: 'Helvetica Neue', 'Helvetica', 'Arial', san-serif;
      font-size: 73px;
      font-weight: bold;
      line-height: 28px;
      margin: 20px 0px 20px 0px;
    }
    .wrapper {
      width: 500px;
      margin: 0 auto;
      clear: both;
    }
    p {
      margin-top: 0px;
      line-height: 1.5em;
    }
    #header {
      background-color: #ffffcc;
      display: block;
      padding: 2px 0;
      margin: 35px 0px 10px 0px;
      border-top: 1px solid #ffcc66;
      border-bottom: 1px solid #ffcc66;
    }
    a {
      color: #6b8df2;
      text-decoration: none;
    }
    .meta {
      padding: 7px 7px 7px 7px;
      background-color: #ffccff;
      border-top: 1px solid #cc99ff;
      border-bottom: 1px solid #cc99ff;
      font-size: 14px;
      display: block;
      margin: 10px 0px 10px 0px;
    }
  </style>
</head>
<body>
  <div id="header">
    <div class="wrapper">
      <h1>CloudKit</h1>
    </div>
  </div>
  <div class="meta">
    <p class="wrapper">
      This page is appearing because you have not set up a default app in your
      rackup file. To learn more about CloudKit, check out
      <a href="http://getcloudkit.com">the site</a>.
    </p>
  </div>
</body>
</html>
HTML
    end
  end
end
