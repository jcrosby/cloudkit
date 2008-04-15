Dir.foreach(File.dirname(__FILE__) + '/resources') do |resource|
  require "resources/#{resource}" unless resource.first == '.'
end