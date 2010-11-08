dir = File.dirname(__FILE__)
require File.expand_path(File.join(dir, 'lib', 'cloudkit', 'version'))

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.name              = "cloudkit"
  s.version           = CloudKit::VERSION
  s.date              = "2010-11-08"
  s.summary           = "An Open Web JSON Appliance."
  s.description       = <<-EOD
CloudKit provides schema-free, auto-versioned, RESTful JSON storage with optional OpenID and OAuth support, including OAuth Discovery.

CloudKit is Rack middleware. It can be used on its own or alongside other Rack-based applications or middleware components such as Rails, Merb or Sinatra.
EOD
  s.authors           = ["Jon Crosby"]
  s.email             = "jon@joncrosby.me"
  s.homepage          = "http://getcloudkit.com"

  s.files             = Dir["#{dir}/lib/**/*.rb"] + Dir["#{dir}/examples/**/*"] + Dir["#{dir}/doc/**/*"]
  s.require_paths     = ["lib"]
  s.test_files        = Dir["#{dir}/spec/**/*.rb"]

  s.executables       = ["cloudkit"]

  s.rubyforge_project = "cloudkit"

  s.add_dependency 'rack', '~> 1.1'
  s.add_dependency 'uuid', '= 2.0.1'
  s.add_dependency 'oauth', '~> 0.3'
  s.add_dependency 'ruby-openid', '~> 2.1'
  s.add_dependency 'json', '~> 1.4.6'
  s.add_dependency 'formatador',  '0.0.10'
  s.add_dependency 'mongo', '~> 1.1.2'
  s.add_dependency 'bson', '~> 1.1.2'
  s.add_dependency 'bson_ext', '~> 1.1.2'
end
