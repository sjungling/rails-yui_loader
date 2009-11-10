#!/usr/bin/env ruby 
require 'rubygems'
require 'active_support'

module Yui #:nodoc:
  class Library #:nodoc:
    attr_accessor :base, :skin, :modules, :satisfaction_map, :required
    def initialize(y_base, y_skin, y_modules = [])
      @base             = y_base
      @skin             = y_skin
      @modules          = []
      @satisfaction_map = {}
      @required         = []
      y_modules.each do |m|
        @modules << Yui::Mod.new(m.first, 
          m.last['type'], 
          m.last['path'], 
          m.last['requires'], 
          m.last['supersedes'], 
          m.last['optional'], 
          m.last['after'], 
          m.last['pkg'], 
          m.last['rollup'], 
          m.last['skinnable'])
      end
    end
    
    def find(mod)
      modules.each do |m|
        return m if m.name == mod
      end
      return nil
    end
    
    def find_all(mod)
      return modules.collect{|m| m if m.name.include?(mod)}.compact
    end
    
    def find_rollup(mod)
      modules.each do |m|
        unless m.supersedes.nil? or m.supersedes.empty?
          return m.name if m.supersedes.include?(mod)
        end
      end
    end
    
    def examine_mod(mod)
      return find(mod).inspect
    end
    
    def rollup_modules
      modules.each do |mod|
        unless mod.supersedes.nil? or mod.supersedes.empty?
          mod.supersedes.each do |sup|
            satisfaction_map[sup] = { mod.name => true }
          end
        end
      end
      return satisfaction_map
    end

    def calculate_dependencies(mod)
      m = find(mod)
      required << mod
      unless m.requires.nil? or m.requires.empty?
        unless m.optional.nil? or m.optional.empty?
          (m.requires + m.optional).each { |mod| get_all_dependencies(mod)}
        else
          m.requires.each { |mod| get_all_dependencies(mod) }
        end
      end
      required << mod
    end

    def get_all_dependencies(mod)
      calculate_dependencies(mod)
      required.uniq!
    end
    
  end
  
  class Mod #:nodoc:
    attr_reader :name, :type, :path, :requires, :supersedes, :skinnable, :optional, :after, :package, :rollup
    def initialize(mod_name, mod_type, mod_path, mod_requires = [], mod_supersedes = [], mod_optional =[], mod_after = [], mod_package = nil, mod_rollup = nil, mod_skinnable = true)
      @name       = mod_name
      @type       = mod_type
      @path       = mod_path
      @requires   = mod_requires
      @supersedes = mod_supersedes
      @skinnable  = mod_skinnable
      @optional   = mod_optional
      @after      = mod_after
      @package    = mod_package
      @rollup     = mod_rollup
    end

    def skinnable?
      return skinnable
    end
    
  end
  
end



yui_version = "2.7.0"
json_config_file = [File.dirname(__FILE__),"/../" , '/meta/json_', yui_version, '.txt'].join()
yui_current = ActiveSupport::JSON.decode(File.read(json_config_file)) if (File.exist?(json_config_file))

@y = Yui::Library.new(yui_current['base'], yui_current['skin'], yui_current['moduleInfo'])
tab = @y.find("tabview")

# @required = []
# @required << tab
# tab.requires.each do |m|
#   @required << @get_all_dependencies(m.name)
# end

# puts @y..size
@y.get_all_dependencies(tab.name).each do |a|
  puts @y.examine_mod(a)
end

# @new_req = @required
# @required.uniq!.each do |r|
#   puts r.name
#   ru = @y.find_rollup(r)
#   ru.each {|r| @new_req << r unless @new_req.include?(r)}
# end

# puts @new_req.uniq.inspect
# puts @y.rollup_modules.to_yaml
# puts @y.examine_mod(tab.name)