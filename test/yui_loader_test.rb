require 'test_helper'

class YuiLoaderTest < ActiveSupport::TestCase

  def setup
    @controller = ActionController::Base.new
    @y = Yui::Loader.new('2.7.0')
  end 
  
  test "yui loader exists" do
    assert @y
  end
  
  test "no version defined" do
    assert_raise(ArgumentError) do
     @yui = Yui::Loader.new
    end
  end
  
  test "no version available" do
    assert_raise(RuntimeError) do
      @yui = Yui::Loader.new("2.5.0")
    end
  end
  
  test "lots of modules" do
    @y.load(["tabview","menu","grids"])
    puts "\n"
    assert @y.tags
  end

  test "load optionals and combine" do
    @y.load_optional = true
    @y.combine = true
    @y.load(["tabview","menu","grids"])
    puts "\nload optionals and combine"
    puts @y.tags
  end

  test "no optionals and combine" do
    @y.load_optional = false
    @y.combine = true
    @y.load(["tabview","menu","grids"])
    puts "\nno optionals and combine"
    puts @y.tags
  end

  test "load optionals and don't combine" do
    @y.load_optional = true
    @y.combine = false
    @y.load(["tabview","menu","grids"])
    puts "\nload optionals and don't combine"
    puts @y.tags
  end

  
  test "no optionals and don't combine" do
    @y.load_optional = false
    @y.combine = false
    @y.load(["tabview","menu","grids"])
    puts "\nno optionals and don't combine"
    puts @y.tags
  end
  
  test "css tags only" do
    @y.load(['tabview', 'grids'])
    puts "\ncss tags only"
    puts @y.tags(:css)
  end
  
  test "js tags only" do
    @y.load(["tabview", "grids"])
    puts "\njs tags only"
    puts @y.tags(:j)
  end
  

end