require 'rake/clean'

CLEAN.include 'doc/api'

task :default => :test

desc 'Run specs'
task :test => FileList['test/*_test.rb'] do |t|
  suite = t.prerequisites.map{|f| "-r#{f.chomp('.rb')}"}.join(' ')
  sh "ruby -Ilib:test #{suite} -e ''", :verbose => false
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
    --exclude=test/*
    --exclude=doc/index.html
    --exclude=doc/curl.html
    --exclude=doc/rest-api.html
    --exclude=doc/main.css
    --op=doc/api
  SH
end
