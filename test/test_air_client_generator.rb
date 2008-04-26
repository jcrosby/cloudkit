require File.join(File.dirname(__FILE__), "test_generator_helper.rb")

class TestAirClientGenerator < Test::Unit::TestCase
  include RubiGen::GeneratorTestHelper

  def setup
    bare_setup
  end
  
  def teardown
    bare_teardown
  end
  
  def test_generator_without_options
    name = "myapp"
    run_generator('air_client', [name], sources)
    assert_directory_exists 'clients/air/build'
    assert_directory_exists 'public/air'
    %w(clients/air/app.html clients/air/app.xml clients/air/AIRAliases.js clients/air/servicemonitor.swf).each do |f|
      assert_generated_file f
    end
  end
  
  private
  def sources
    [RubiGen::PathSource.new(:test, File.join(File.dirname(__FILE__),"..", generator_path))
    ]
  end
  
  def generator_path
    "generators"
  end
end
