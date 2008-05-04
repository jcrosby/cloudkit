= cloudkit

http://kaboomerang.com
http://github.com/jcrosby/cloudkit/tree/master

== DESCRIPTION:

CloudKit provides a framework for building synchronized Open Web applications that run in and out of the browser, online and offline, using technologies like OpenID, OAuth, HTML, JavaScript, CSS, and REST web services.

== FEATURES:

* App generator with OpenID and OAuth support built in
* Runs on the fast and furious Sinatra/Thin combo
* Generates GWT clients that use GWT-REST instead of GWT-RPC
* Generates synchronized model objects (RESTful resource -> GWT JavaScript model)
* Generates desktop apps via Adobe AIR
* Generates desktop SQLite migrations automatically

== SYNOPSIS:

Build an app that supports OpenID and OAuth:

> cloudkit myapp

Create a database and run the app:

> mysqladmin -uroot create myapp_development
> cd myapp
> rake db:migrate
> rake start

Create a GWT client:

> script/generate gwt_client --gwt-home=/usr/local/lib/gwt
> rake gwt:compile

Run your client as a desktop app:

> script/generate air_client
> rake air:debug

Add a RESTful resource that is mirrored in your GWT/AIR clients, including desktop SQLite migrations:

> script/generate gwt_resource ActionItem
> rake db:migrate

== REQUIREMENTS:

* Gems: sinatra, ruby-openid, oauth, json, activerecord, sqlite3-ruby

== INSTALL:

rake local_deploy (until the gem is released officially)

== LICENSE:

GWTx - Apache License 2.0 - http://www.apache.org/licenses/LICENSE-2.0
Gwittir - LGPL http://www.gnu.org/licenses/lgpl.html

Everything else:

The MIT License

Copyright (c) 2008 Jon Crosby

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.