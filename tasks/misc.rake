require 'fileutils'

desc 'update gwt-cloudkit.jar'
task :update_gwt do
  cd '../gwt-cloudkit'
  sh 'ant clean'
  sh 'ant package'
  cp 'gwt-cloudkit.jar', '../cloudkit/generators/gwt_client/templates/lib/'
end