require 'rake/clean'
require 'spec/rake/spectask'

CLEAN.include 'doc/api'

task :default => :spec

desc "Run all examples (or a specific spec with TASK=xxxx)"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts  = ["-c"]
  t.spec_files = begin
    if ENV["TASK"] 
      ENV["TASK"].split(',').map { |task| "spec/**/#{task}_spec.rb" }
    else
      FileList['spec/**/*_spec.rb']
    end
  end
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
