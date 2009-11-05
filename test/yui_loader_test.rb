require 'test_helper'

class YuiLoaderTest < ActiveSupport::TestCase

  def setup
    @controller = ActionController::Base.new
    @y = Yui::Loader.new('3.0.0b1')
  end 
  
  # test "yui loader exists" do
  #   assert @y
  # end
  # 
  # test "for dirty state before and after" do
  #   assert @y.dirty, false
  #   @y.load(['reset'])
  #   assert @y.dirty, true
  # end
  # 
  # test "right version of yui" do
  #   assert @y.combo_default_version, "2.7.0"
  # end
  # 
  # test "requests the right modules" do
  #   @y.load(['grids'])
  #   assert_equal @y.requests, {"grids" => "grids"}
  #   assert_not_equal @y.requests, {"fonts" => "fonts" }
  #   
  #   @yui = Yui::Loader.new('2.7.0')
  #   @yui.load(['tabview','fonts'])
  #   assert_not_equal @yui.requests, {"tabview" => "tabview", "grids" => "grids", "fonts" => "fonts"}
  #   assert_equal @yui.requests, {"tabview" => "tabview", "fonts" => "fonts"}
  #   assert_equal @yui.requests, {"fonts" => "fonts", "tabview" => "tabview" }
  # end
  # 
  # test "no version defined" do
  #   assert_raise(ArgumentError) do
  #    @yui = Yui::Loader.new
  #   end
  # end
  # 
  # test "no version available" do
  #   assert_raise(RuntimeError) do
  #     @yui = Yui::Loader.new("2.5.0")
  #   end
  # end
  # 
  # test "css embed" do
  #   @y.load(['reset'])
  #   assert @y.css_embed
  # end
  # 
  # test "css json" do
  #   @y.load(['reset'])
  #   assert @y.css_json
  # end
  # 
  # test "css data" do
  #   @y.load(['reset'])
  #   assert @y.css_data
  # end
  # 
  # test "css raw" do
  #   @y.load(['reset'])
  #   assert_raise(RuntimeError) do 
  #     @y.css_raw
  #   end
  # end
  # 
  # test "js embed" do
  #   @y.load(["dom"])
  #   assert @y.script_embed
  # end
  # 
  # test "js json" do
  #   @y.load(['dom'])
  #   assert @y.script_json, nil
  # end
  # 
  # test "js data" do
  #   @y.load(['dom'])
  #   assert @y.script_data
  # end
  # 
  # test "js raw" do
  #   @y.load(['dom'])
  #   assert_raise(RuntimeError) do 
  #     @y.script_raw
  #   end
  # end
  # 
  # test "lots of modules" do
  #   @y.load(["tabview","menu","grids"])
  #   assert @y.tags
  # end
  # 
  # test "get loaded modules" do
  #   @y.load(['grids'])
  #   assert @y.get_loaded_modules
  # end
  
  test "load optional" do
    # @y.load_optional = true
    # @y.combine = true
    @y.load(["node-menunav"])
    assert @y.tags
  end
end