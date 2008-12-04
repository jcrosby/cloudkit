task :default => :test

desc 'Run specs'
task :test => FileList['test/*_test.rb'] do |t|
  suite = t.prerequisites.map{|f| "-r#{f.chomp('.rb')}"}.join(' ')
  sh "ruby -Ilib:test #{suite} -e ''", :verbose => false
end

desc 'Generate rdoc'
task :rdoc do
  rm_rf 'doc'
  `hanna --inline-source --line-numbers --include=lib/cloudkit.rb --include=lib/cloudkit/*.rb --include=lib/cloudkit/*/*.rb --exclude=templates/* --exclude=test/*`
end
