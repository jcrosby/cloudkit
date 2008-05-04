require File.join(File.dirname(__FILE__), "test_generator_helper.rb")

class TestGwtClientGenerator < Test::Unit::TestCase
  include RubiGen::GeneratorTestHelper

  def setup
    bare_setup
  end
  
  def teardown
    bare_teardown
  end
  
  def test_generator_without_options
    name = "myapp"
    run_generator('gwt_client', [name], sources)
    assert_directory_exists 'clients/gwt/lib'
    assert_directory_exists 'clients/gwt/src/ui/client/resource'
    assert_directory_exists 'clients/gwt/src/ui/client/migration'
    %w(clients/gwt/UI-compile clients/gwt/UI-shell clients/gwt/lib/gwt-rest.jar clients/gwt/lib/gwtx.jar clients/gwt/lib/gwt-cloudkit.jar clients/gwt/lib/gwittir-core-0.3.jar clients/gwt/src/ui/UI.gwt.xml clients/gwt/src/ui/client/AppEntryPoint.java).each do |f|
      assert_generated_file f
    end
    assert_generated_file 'views/ui.erb' do |f|
      f =~ /New CloudKit UI/
    end
  end
  
  private
  def sources
    [RubiGen::PathSource.new(:test, File.join(File.dirname(__FILE__),"..", generator_path))]
  end
  
  def generator_path
    "generators"
  end
end
