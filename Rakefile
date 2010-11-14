require 'rake/clean'

require 'rspec/core'
require 'rspec/core/rake_task'

CLEAN.include 'doc/api'

task :default => :spec

desc "Run all specs in spec directory"
RSpec::Core::RakeTask.new do |task|
  task.rspec_opts = ["-c"]
end

desc 'Generate rdoc'
task :rdoc do
  rm_rf 'doc/api'
  sh((<<-SH).gsub(/[\s\n]+/, ' ').strip)
  hanna
    --inline-source
    --line-numbers
    --include=lib/cloudkit.rb
    --include=lib/cloudkit/*.rb
    --include=lib/cloudkit/*/*.rb
    --exclude=Rakefile
    --exclude=TODO
    --exclude=cloudkit.gemspec
    --exclude=templates/*
    --exclude=examples/*
    --exclude=spec/*
    --exclude=doc/index.html
    --exclude=doc/curl.html
    --exclude=doc/rest-api.html
    --exclude=doc/main.css
    --op=doc/api
  SH
end
