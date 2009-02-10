Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.name              = "cloudkit"
  s.version           = "0.11.0"
  s.date              = "2008-02-09"
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
    lib/cloudkit/store/document.rb
    lib/cloudkit/store/extraction_view.rb
    lib/cloudkit/store/response.rb
    lib/cloudkit/store/response_helpers.rb
    lib/cloudkit/templates/authorize_request_token.erb
    lib/cloudkit/templates/oauth_descriptor.erb
    lib/cloudkit/templates/oauth_meta.erb
    lib/cloudkit/templates/openid_login.erb
    lib/cloudkit/templates/request_authorization.erb
    lib/cloudkit/templates/request_token_denied.erb
    lib/cloudkit/user_store.rb
    lib/cloudkit/util.rb
    test/document_test.rb
    test/ext_test.rb
    test/flash_session_test.rb
    test/helper.rb
    test/oauth_filter_test.rb
    test/oauth_store_test.rb
    test/openid_filter_test.rb
    test/openid_store_test.rb
    test/rack_builder_test.rb
    test/request_test.rb
    test/service_test.rb
    test/store_test.rb
    test/user_store_test.rb
    test/util_test.rb
  ]
  s.test_files        = s.files.select {|path| path =~ /^test\/.*_test.rb/}
  s.rubyforge_project = "cloudkit"
  s.rubygems_version  = "1.1.1"
  s.add_dependency 'rack', '~> 0.9'
  s.add_dependency 'rack-config', '>= 0.9'
  s.add_dependency 'uuid', '= 2.0.1'
  s.add_dependency 'dm-core', '~> 0.9.10'
  s.add_dependency 'dm-validations', '~> 0.9.10'
  s.add_dependency 'oauth', '~> 0.3'
  s.add_dependency 'ruby-openid', '= 2.1.2'
  s.add_dependency 'json', '= 1.1.3'
  s.add_dependency 'sqlite3-ruby', '= 1.2.4'
end
