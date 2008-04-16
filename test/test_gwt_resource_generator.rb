require File.join(File.dirname(__FILE__), "test_generator_helper.rb")

class TestGwtResourceGenerator < Test::Unit::TestCase
  include RubiGen::GeneratorTestHelper

  def setup
    bare_setup
  end
  
  def teardown
    bare_teardown
  end
  
  def test_generator_without_options
    name = "ActionItem"
    run_generator('gwt_resource', [name], sources)
    assert_generated_file "resources/action_items.rb"
    assert_generated_file "db/migrate/001_create_action_items.rb"
    assert_generated_file "clients/gwt/src/ui/client/resource/ActionItem.java"
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
