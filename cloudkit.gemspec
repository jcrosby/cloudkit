Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.name              = "cloudkit"
  s.version           = "0.11.1"
  s.date              = "2008-03-24"
  s.summary           = "An Open Web JSON Appliance."
  s.description       = "An Open Web JSON Appliance."
  s.authors           = ["Jon Crosby"]
  s.email             = "jon@joncrosby.me"
  s.homepage          = "http://getcloudkit.com"
  s.files             = %w[
    CHANGES
    COPYING
    README
    Rakefile
    TODO
    cloudkit.gemspec
    doc/curl.html
    doc/images/example-code.gif
    doc/images/json-title.gif
    doc/images/oauth-discovery-logo.gif
    doc/images/openid-logo.gif
    doc/index.html
    doc/main.css
    doc/rest-api.html
    examples/1.ru
    examples/2.ru
    examples/3.ru
    examples/4.ru
    examples/5.ru
    examples/6.ru
    examples/TOC
    lib/cloudkit.rb
    lib/cloudkit/constants.rb
    lib/cloudkit/exceptions.rb
    lib/cloudkit/flash_session.rb
    lib/cloudkit/oauth_filter.rb
    lib/cloudkit/oauth_store.rb
    lib/cloudkit/openid_filter.rb
    lib/cloudkit/openid_store.rb
    lib/cloudkit/rack/builder.rb
    lib/cloudkit/rack/router.rb
    lib/cloudkit/request.rb
    lib/cloudkit/service.rb
    lib/cloudkit/store.rb
    lib/cloudkit/store/memory_table.rb
    lib/cloudkit/store/resource.rb
    lib/cloudkit/store/response.rb
    lib/cloudkit/store/response_helpers.rb
    lib/cloudkit/templates/authorize_request_token.erb
    lib/cloudkit/templates/oauth_descriptor.erb
    lib/cloudkit/templates/oauth_meta.erb
    lib/cloudkit/templates/openid_login.erb
    lib/cloudkit/templates/request_authorization.erb
    lib/cloudkit/templates/request_token_denied.erb
    lib/cloudkit/uri.rb
    lib/cloudkit/user_store.rb
    lib/cloudkit/util.rb
    spec/ext_spec.rb
    spec/flash_session_spec.rb
    spec/memory_table_spec.rb
    spec/oauth_filter_spec.rb
    spec/oauth_store_spec.rb
    spec/openid_filter_spec.rb
    spec/openid_store_spec.rb
    spec/rack_builder_spec.rb
    spec/request_spec.rb
    spec/resource_spec.rb
    spec/service_spec.rb
    spec/spec_helper.rb
    spec/store_spec.rb
    spec/uri_spec.rb
    spec/user_store_spec.rb
    spec/util_spec.rb
  ]
  s.test_files        = s.files.select {|path| path =~ /^spec\/.*_spec.rb/}
  s.rubyforge_project = "cloudkit"
  s.rubygems_version  = "1.1.1"
  s.add_dependency 'rack', '~> 0.9'
  s.add_dependency 'uuid', '= 2.0.1'
  s.add_dependency 'oauth', '~> 0.3'
  s.add_dependency 'ruby-openid', '= 2.1.2'
  s.add_dependency 'json', '= 1.1.3'
end
