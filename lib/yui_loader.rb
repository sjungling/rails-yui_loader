require 'md5'
require 'net/http'
require "curl"
require 'ruby-debug'

module Yui #:nodoc:
  YUI_AFTER      = 'after'
  YUI_BASE       = 'base'
  YUI_CSS        = 'css'
  YUI_DATA       = 'DATA'
  YUI_DEPCACHE   = 'depCache'
  YUI_DEBUG      = 'DEBUG'
  YUI_EMBED      = 'EMBED'
  YUI_FILTERS    = 'filters'
  YUI_FULLPATH   = 'fullpath'
  YUI_FULLJSON   = 'FULLJSON'
  YUI_GLOBAL     = 'global'
  YUI_JS         = 'js'
  YUI_JSON       = 'JSON'
  YUI_MODULES    = 'modules'
  YUI_NAME       = 'name'
  YUI_OPTIONAL   = 'optional'
  YUI_OVERRIDES  = 'overrides'
  YUI_PATH       = 'path'
  YUI_PKG        = 'pkg'
  YUI_PREFIX     = 'prefix'
  YUI_PROVIDES   = 'provides'
  YUI_RAW        = 'RAW'
  YUI_REPLACE    = 'replace'
  YUI_REQUIRES   = 'requires'
  YUI_ROLLUP     = 'rollup'
  YUI_SATISFIES  = 'satisfies'
  YUI_SEARCH     = 'search'
  YUI_SKIN       = 'skin'
  YUI_SKINNABLE  = 'skinnable'
  YUI_SUPERSEDES = 'supersedes'
  YUI_TAGS       = 'TAGS'
  YUI_TYPE       = 'type'
  YUI_URL        = 'url'
  
  module LoaderHelper #:nodoc:
    # NOTE: Proof of concept for future
    def yui_css(version, format = YUI_TAGS, modules = [], load_opt = false, load_combo = true)
      y = Yui::Loader.new(version)
      y.load_optional = load_opt
      y.combine = load_combo
      y.load(modules)
      y.css
    end
    
    def yui_js(version, format = YUI_TAGS, modules = [], load_opt = false, load_combo = true)
      y = Yui::Loader.new(version)
      y.load_optional = load_opt
      y.combine = load_combo
      y.load(modules)
      y.js
    end
  end
  
  
  # = Yui::Loader
  # 
  # YuiLoader is a Ruby on Rails plugin based upon the YUI PHPLoader scripts by Yahoo!
  # 
  # == Required Constructor Attributes
  #   - yui_version:    Version of YUI library to load. Must have matching meta file
  # == Optional Constructor Attributes
  #   - cache_key:      Used to generate unique key if caching is enabled
  #   - modules:        Custom module data. See below for examples
  #   - no_yui:         Don't use the YUI library, but just custom modules
  # 
  # == Optional Configurations
  #   - allow_rollups: (boolean) Aggregate the like files into a single request. 
  #                     Default: true
  #   - base:          (String) Specify a different YUI build directory path
  #                      Default: http://yui.yahooapis.com/YUI_VERSION/build/
  #   - combine:       (boolean) If set to true, YUI files will be combined into a
  #   single request using the combo service provided on the Yahoo! CDN
  #                       Default: true  
  #   - combo_base:    (string) The base path to the Yahoo! CDN service. 
  #                       Default: "http://yui.yahooapis.com/combo? 
  #   - filter:        (String) Filter to apply to urls. Options are:
  #                      YUI_DEBUG                                                          
  #                        Selects the debug versions of the library (e.g., event-debug.js).
  #                        This option will automatically include the logger widget         
  #                      YUI_RAW                                                            
  #                        Selects the non-minified version of the library (e.g., event.js).
  # 
  #   - load_optional: (boolean) Should loader load optional dependencies for the
  #   components you're requesting? 
  #                     Default: false.
  # 
  # == Constructor Examples
  # 
  #   @yahoo = Yui::Loader.new("2.8.0")
  #   @yahoo.load_optional = true
  #   @yahoo.load(["grids"])
  # 
  class Loader


    attr_accessor :load_optional, :combine, :combo_base, :allow_rollups, :base, :filter
    def initialize(yui_version, cache_key = nil, modules = nil, no_yui = false)

      # Combined into a single request using the combo service to potentially reduce the number of http requests required
      @combine = true

      # Should we allow rollups
      @allow_rollups = true

      # Whether or not to load optional dependencies
      @load_optional = false

      # # Force rollup modules 
      # @rollups_to_top = false

      # keeps track of modules
      @processed_module_types = Hash.new
      
      # all required modules
      @required_modules = Hash.new
      
      # Modules that have been outputted via getLink
      @loaded = Hash.new
      
      # list of all modules superseded by the list of required modiles
      # TODO evaluate necessity
      # @superseded = Hash.new
      
      # track undefined modules
      @undefined_modules = Hash.new

      # Loader state, when false we're ready to generate some fu
      @dirty = true
      
      # Modules
      @sorted = Array.new

      # Modules that have been loaded ? 
      @accounted_for = Hash.new

      # A list of modules to apply the filter to.
      @filter_list = nil

      # required skins
      @skins = Array.new

      # Available modules from the particular version of YUI
      @modules = Hash.new

      # Var name says it all
      @full_cache_key = nil

      # Data about new build directory location
      @base_overrides = Hash.new

      # Were we able to locate cached data?
      @cache_found = false

      # Should we delay storing data to cache?
      @delay_cache = false

      # cache busting hack for environs that use same path for current vers of lib
      @version = nil

      # Unidentified fu
      @version_key = "_yuiversion"

      # What skin are we using?
      @skin = Hash.new

      # Available rollup modules (e.g. reset-fonts-grids.css for ['reset','fonts','grids'])
      @rollup_modules = Hash.new
      
      # Global Modules
      @global_modules = Hash.new
      
      # Shows what modules are satisified by rollup modules 
      @satisfaction_map = Hash.new
      
      # Temp variable (best I can tell)
      @dependencies_cache = Hash.new
      
      # Filters supplied by user: YUI_DEBUG or YUI_RAW
      @filters = {
        'YUI_RAW' => {
          'YUI_SEARCH'  => '-min\.js',
          'YUI_REPLACE' => '.js'
        },
        'YUI_DEBUG' => {
          'YUI_SEARCH'  => '-min\.js',
          'YUI_REPLACE' => '-debug.js'
        }
      }


      # base path to combo service
      @combo_base = "http://yui.yahooapis.com/combo?"

      unless yui_version
        raise "ERROR: the first parameter of Yui::Loader must be the version of YUI you want to use"
      end
    
      # Load up the JSON config file from ../meta/
      json_config_file = [File.dirname(__FILE__),"/../" , '/meta/json_', yui_version, '.txt'].join()

      if (File.exist?(json_config_file))
        @yui_current = ActiveSupport::JSON.decode(File.read(json_config_file))
      else
        raise "ERROR: Unable to find a suitable YUI metadata file!"
      end

      # Support for various methods of output
      # TODO: Move these to the eventual Library class as methods (bool)
      @cache_avail           = ActionController::Base.cache_configured?
      @curl_avail            = Curl::Easy.methods.include?('http_get')
      @json_avail            = Rails.methods.include?('to_json')
      @embed_avail           = (@curl_avail and @cache_avail)
      
      if @cache_key and @cache_avail
        @full_cache_key = MD5.hexdigest(@base + @cache_key)
        @cache = Rails.cache.read(@full_cache_key)
        unless @cache.nil?
          @cache_found        = true
          @modules            = cache[YUI_MODULES]
          @skin               = cache[YUI_SKIN]
          @rollup_modules     = cache[YUI_ROLLUP]
          @global_modules     = cache[YUI_GLOBAL]
          @satisfaction_map   = cache[YUI_SATISFIES]
          @dependencies_cache = cache[YUI_DEPCACHE]
          @filters            = cache[YUI_FILTERS]
        end
      end

      # Load some default data from the meta file
      @base                  = @yui_current[YUI_BASE]
      @combo_default_version = yui_version

      # == Module Set-up
      # Load modules from meta file then merge with any custom module definitions
      @modules = @yui_current['moduleInfo']
      
      # merge modules if we have some custom modules
      @modules.merge!(modules.to_hash) unless modules.nil?

      # Seperate global modules and rollup modules
      # TODO: Abstract YUI Modules into their own class with global/rollup as [r] attributes
      @modules.each do |name, mod|
        @global_modules[name] = true if mod[YUI_GLOBAL]
        if mod[YUI_SUPERSEDES]
          @rollup_modules[name] = mod
          mod[YUI_SUPERSEDES].each {|sup| map_satisfying_module(sup,name)}
        end
      end
      
      # Skin set-up
      @skin = @yui_current[YUI_SKIN]
      @skin['overrides'] = Hash.new
      @skin[YUI_PREFIX] = 'skin-'

    end

    # Used to load YUI and/or custom components
    # 
    # ==== Required Parameters
    #   - components: (array)
    # ==== Example
    #   @y.load(['tabview', 'menu', 'grids'])
    # 
    def load(components = [])
      raise "Components must be defined in an array" if components.empty?
      components.each { |c| load_single(c)}
    end
    
    # Filter the processed dependencies by module type (JS or CSS)
    # 
    # ==== Params
    #   - modules: (array)
    #   - module_type: (string)
    # ==== Example
    # 
    #   css = filter_dependencies([{'name'=>'grids', 'type'=>'css'}, {'name'=>'dom', 'type'=>'js'}], YUI_CSS)
    #   # => [{'name'=>'grids', 'type'=>'css'}]
    # 
    def filter_dependencies(modules, module_type)
      return modules.select{|mods| mods if mods['type'].include?(module_type)}.flatten
    end

    # Returns appropriate tags for the loaded mofules
    # 
    # ==== Optional Parameters
    #   - format: (string) Default to nil
    #   - module_type: (string) Default to nil
    #   - skip_sort: (boolean) Default to false
    # 
    # ==== Example
    #   @y.Yui::Loader.new("2.7.0")
    #   @y.load_optional = true
    #   @y.combine = true
    #   @y.load(["tabview","menu","grids"])
    #   @y.tags
    # 
    #   # => <link rel="stylesheet" href="[REDACTED].css" type="text/css" charset="utf-8" />
    #   # => <script type="text/javascript" charset="utf-8" src="[REDACTED].js"></script>
    def tags(format = nil, module_type = nil, skip_sort = false)
      dependencies = process_dependencies(YUI_TAGS, module_type, skip_sort)
      html = String.new
      if format == :css or format.nil?
        css = filter_dependencies(dependencies, YUI_CSS)
        html += get_stylesheet_tag(css)
      end
      if format == :js or format.nil?
        js = filter_dependencies(dependencies, YUI_JS)
        html += get_javascript_tag(js)
      end
      return html
    end

    # Returns the appropriate SCRIPT tag based upon modules that have been requested as well as combo option
    # 
    # ==== Required Modules
    #   - mods: (array)
    # 
    # ==== Example
    # 
    #   output = get_javascript_tag(['name' => 'tabview'])
    #   # => <script type="text/javascript" charset="utf-8" src="http://yahoo.com/combo?2.7.0/build/tabview/tabview-min.js"></script>
    # 
    def get_javascript_tag(modules)
      html = String.new
      if @combine
        combo = []
        modules.each do |mod|
          combo << mod['path']
        end
        html += '<script type="text/javascript" charset="utf-8" src="' + @combo_base + combo.join("&") + '"></script>' + "\n"
      else
        modules.each do |mod|
          html += '<script type="text/javascript" charset="utf-8" src="' + @combo_base + mod['path'] + '"></script>' + "\n"
        end
      end
      return html
    end

    # Returns the appropriate link tag based upon modules that have been requested as well as combo option
    # 
    # ==== Required Modules
    #   - mods: (array)
    # 
    # ==== Example
    # 
    #   output = get_stylesheet_tag(['name' => 'tabview', 'type' => 'css', 'path' => '2.7.0/build/grids/grids-min.css'])
    #   # => <link type="stylesheet" charset="utf-8" type="text/css" href="http://yahoo.com/combo?2.7.0/build/grids/grids-min.css" />
    # 
    def get_stylesheet_tag(modules)
      html = String.new
      if @combine
        combo = []
        modules.each do |mod|
          combo << mod['path']
        end
        html += '<link rel="stylesheet" href="'+ @combo_base + combo.join("&") + '" type="text/css" charset="utf-8" />' + "\n"
      else
        modules.each do |mod|
          html += '<link rel="stylesheet" href="'+ @combo_base + mod['path'] + '" type="text/css" charset="utf-8" />' + "\n"
        end
      end
      
      return html
    end
    
    protected

    # Check off the module as ready to be loaded
    # 
    # ==== Required Parameters
    #   - name: (array)
    # 
    def account_for(name)
      # add current module to the array of modules that have been processed
      @accounted_for[name] = name
      
      # if the instance modules already has the current module, 
      # add any modules that supersede the current module to the array of modules
      # that have been processed
      if @modules.has_key?(name)
        get_superseded(name).each do |supname, val|
          @accounted_for[supname] = true
        end
      end
    end

    # Inspite of this methods name, if there's a module type defined, 
    # find any new dependencies
    # 
    # ==== Required Paramters
    #   - dependencies: (array)
    #   - module_type: (string)
    # 
    # ==== Returns
    #   - (array) of dependencies
    # 
    def prune(dependencies, module_type)
      puts "PRUNE:\tdependencies\t#{dependencies.inspect}\tmodule_type\t#{module_type}"
      unless module_type.nil?
        new_dependencies = Hash.new
        dependencies.each do |name, val|
          new_dependencies[name] = true if (not name.nil? and @modules[name][YUI_TYPE].include?(module_type))
        end
        return new_dependencies
      else
        return dependencies
      end
    end
  
  
    # Finds modules that supersede the current module being processed
    # 
    # ==== Required Parameter
    #   - name: (string)
    # 
    # ==== Returns
    #   - (array)
    def get_superseded(name)
      puts "get_superseded\tname\t#{name}"
      key = YUI_SUPERSEDES + name
      supersedes = Hash.new
      return @dependencies_cache[key] unless @dependencies_cache[key].nil?

      if @modules.has_key?(name)
        # if the current modules has modules that supersede it, let's get those modules!
        unless @modules[name][YUI_SUPERSEDES].nil?
          @modules[name][YUI_SUPERSEDES].each  do |superseder|
            supersedes[superseder] = true
            supersedes.merge!(@get_superseded[superseder]) if @modules[superseder]
          end
        end
      end

      @dependencies_cache[key] = supersedes
      return supersedes
    end
  
  
    # Determine if any of the modules we've requested requires a skin
    # 
    # ==== Required Paramters
    #   - name: (string)
    # 
    # ==== Return
    #   - (string)
    # 
    def skin_setup(name)
      skin_name = nil
      dep = @modules[name]
  
      if dep and dep[YUI_SKINNABLE]
        
        current_skin = @skin
        
        unless current_skin[YUI_OVERRIDES].empty? and current_skin[YUI_OVERRIDES][name].nil?
          current_skin[YUI_OVERRIDES][name].each do |name, over|
            skin_name = format_skin(over, name)
          end
        else
          skin_name = format_skin(s['defaultSkin'], name)
        end
        
        @skins << skin_name
        skin = parse_skin(skin_name)
    
        if skin.size == 3
          dep = @modules[skin[2]]
          package = dep[YUI_PKG] ? dep[YUI_PKG] : skin[2]
          path = "#{package}/#{current_skin[YUI_BASE]}#{skin[1]}/#{skin[2]}.css"
          @modules[skin_name] = { "name" => skin_name, "type" => YUI_CSS, "path" => path, "after" => current_skin[YUI_AFTER] }
        else
          path = "#{current_skin[YUI_BASE]}#{current_skin[1]}/#{current_skin[YUI_PATH]}"
          new_mod = {"name" => skin_name, "type" => YUI_CSS, "path" => path, "rollup" => 3, "after" => current_skin[YUI_AFTER] }
          @modules[skin_name] = new_mod
          @rollup_modules[skin_name] = new_mod
        end
      end

      return  skin_name
    end
  
    
    # Identify dependencies for a give module name
    # 
    # ==== Required Paramters
    #   - module_name: (string)  Module name
    # 
    # ==== Optional Parameters
    #   - load_optional: (boolean) Load optional dependencies
    #   - completed: (array)
    # 
    # ==== Returns
    #   - (array)
    # 
    def get_all_dependencies(module_name, load_optional = false, completed = {})
      key = [YUI_REQUIRES, module_name].join
      key += YUI_OPTIONAL if load_optional
  
      return @dependencies_cache[key] unless @dependencies_cache[key].nil?
  
      mod = @modules[module_name]
      requires = Hash.new
      unless mod[YUI_REQUIRES].nil? or mod[YUI_REQUIRES].empty?
        mod[YUI_REQUIRES].each { |r| requires[r] = true}
      end
  
      if load_optional and not mod[YUI_OPTIONAL].nil?
        mod[YUI_OPTIONAL].each { |opt| requires[opt] = true }
      end
  
      requires.each do |name, value|
        skin_name = skin_setup(name)
        requires[skin_name] = true if skin_name

        if not completed[name] and @modules[name]
          new_requires = get_all_dependencies(name, load_optional, completed)
          requires.merge!(new_requires)
        end
      end
  
      @dependencies_cache[key] = requires
      return requires
    end
  
    # Get global dependencies that were defined by the YUI meta file
    # 
    # ==== Optional Parameter
    #   - module_type: (string)
    # 
    # ==== Returns
    #   - (array) of global modules
    # 
    def get_global_dependencies(module_type = nil)
      return @global_modules
    end
  
    # Check to see if the a module can be satisfied by a rollup / other module
    # 
    # ==== Required Parameters
    #   - satisfied: (string)
    #   - satisfier: (string)
    # 
    # ==== Returns
    #   - (boolean) true if the supplied satisfied module is satisfied by the supplied satisfier module
    # 
    def module_satisfies?(satisfied, satisfier)
      satisfied.include?(satisfier) or (@satisfaction_map.has_key?(satisfied) and @satisfaction_map[satisfied][satisfier])
    end
  
    # Used to override the base directory for specific set of modules (Not supported with combo service)
    # 
    # ==== Required Parameters
    #   - base: (string?)
    #   - modules: (array)
    # 
    def override_base(base, modules)
      # puts "override_base:\tbase#{base.inspect}\tmodules\t#{modules.size}"
      modules.each do |name|
        @base_override[name] = base
      end
    end
  
    def list_satisfies?(satisfied, module_list)
      return true if module_list.has_key?(satisfied)
      if @satisfaction_map.has_key?(satisfied)
        @satisfaction_map[satisfied].each do |name, val|
          return true if module_list.has_key?(name)
        end
      end
      return false
    end

    def check_threshold?(mod, module_list)
      if not module_list.empty? and mod[YUI_ROLLUP].is_a?(Fixnum)
        matched = 0
        thresh = mod[YUI_ROLLUP]
        module_list.each do |mod_list_name, mod_def|
          matched += 1 if mod[YUI_SUPERSEDES].include?(mod_list_name)
        end
        return true  if (matched >= thresh)
      end
      return false
    end
      
    # Only called if the loader is dirty
    def sort_dependencies(module_type, skip_sort = false)
      requires = Hash.new
      top      = Hash.new
      bot      = Hash.new
      not_done = Hash.new
      sorted   = Hash.new
      found    = Hash.new
  
      # add global dependenices so they are included when calculating rollups
      globals = get_global_dependencies(module_type)
  
      globals.each { |name, dep| requires[name] = true }
  
      # get and store the full list of dependencies
      @required_modules.each do |name, val|
        requires[name] = true
        requires.merge!(get_all_dependencies(name, @load_optional))
      end
  
      # if we skip the sort, just return the list that includes everything
      # that was requested, all of their requirements, and global modules.
      # This is filtered by module type if supplied
      return prune(requires, module_type) if skip_sort
  
      # if we are sorting again after new modules have been requested, we do not rollup
      # and we can remove the accounted for modules

      if not @accounted_for.empty? or not @loaded.empty?
        @loaded.merge(@accounted_for).each {|name, value| requires.delete(name)}
      elsif @allow_rollups
        rollups = @rollup_modules
        unless rollups.empty?
          rollups.each do |name, rollup|
            if requires[name].nil? and check_threshold?(rollup, requires)
              requires[name] = true
              requires.merge!(get_all_dependencies(name, @load_optional, requires))
            end
          end
        end
      end
  
      # clear out superseded packages
      requires.each do |name, val|
        @modules[name][YUI_SUPERSEDES].each { |i, val| requires.delete(i) } if @modules[name][YUI_SUPERSEDES]
      end
    
      # move globals to the top
      requires.each do |name, val|
        unless @modules[name][YUI_GLOBAL].nil?
          top[name] = name
        else
          not_done[name] = name
        end
      end
  
      # merge new order if we have globals
      not_done.merge!(top) unless top.empty?

      # keep track of what is accounted for
      @loaded.each { |name, mod| @accounted_for[name] }
  
      # keep going until everything is sorted
      counted = 0
  
      while not not_done.empty?
        return sorted.merge!(not_done) if (counted += 1) > 200
    
        not_done.each do |name, val|
          new_requires = get_all_dependencies(name, @load_optional)
          failed = false
      
          if new_requires.empty?
            sorted[name] = name
            @accounted_for[name]
            not_done.delete(name)
          else
            new_requires.each do |dep_name, dep_val|
              unless @accounted_for[dep_name] and list_satisfies?(dep_name, sorted)
                failed = true
                tmp    = Hash.new
                found  = false
            
                not_done.each do |new_name, new_val|
                  if module_satisfies?(dep_name, new_name)
                    tmp[new_name] = new_name
                    not_done.delete(new_name)
                    found = true
                    break
                  end
                end #end each
            
                if found
                  not_done.merge!(tmp)
                else
                  return sorted.merge!(not_done)
                end #end if
                break
              end #end if/elsif/else
          
              unless failed
                sorted[name] = name
                not_done.delete(name) if account_for(name)
              end #end unless
            end
          end #end if
        end #end each
      end #end when
  
      sorted.each { |name, val| skin_name = skin_setup(name)}

      @skins.each { |name, val| sorted[val] = true} unless @skins.empty?
  
      @dirty = false
      @sorted = sorted
      return prune(sorted, module_type)
    end

    def process_dependencies(output_type, module_type, skip_sort = false, show_loaded = false)
      if show_loaded or (not @dirty and not @sorted.empty?)
        sorted = prune(@sorted, module_type)
      else
        sorted = sort_dependencies(module_type, skip_sort)
      end
      
      final_modules = Array.new
      sorted.each do |name, val|
        if show_loaded or not @loaded[name]
          dep = @modules[name]
          final_modules << add_to_combo(name, dep[YUI_TYPE])
        end
      end
  
      # if the data has not been cached, and we are not running two rotations for separating css and js, cache what we have
      @update_cache if (@cache_avail and @cache_found and @delay_cache)
  

      # after the first pass we no longer try to use meta modules
      set_processed_module_type(module_type)
  
      # keep track of all the stuff that we loaded so that we don't reload
      # script if the page makes multiple calls to tags
      @loaded.merge!(sorted)

      return final_modules
    end

    # Retrieve the calculated url for the component in questio
    # Params: name of the YUI component
    def get_url(name)
      # figure out how to set targets and filters
      url = String.new
      base = @base_overrides.has_key?(name) ? @base_overrides[name] : @base
  
      if @modules.has_key?(name)
        url = @modules[name][YUI_FULLPATH] ? @modules[name][YUI_FULLPATH] : [base, @modules[name][YUI_PATH]].join
      else
        url = [base, name].join
      end
  
      if @filter
        if not @filter_list.empty? and not @filter_list[name]
          # skip filter
        elsif @filters[@filter]
          url.gsub!(filtr[YUI_SEARCH], @filters[@filter][YUI_REPLACE])
        end
      end
  
      if @version
        pre = url.include?('?') ? "&" : "?"
        url += "#{pre}#{@version_key}=#{@version}"
      end

      return url
    end

    # Retrieve the contents of a remote resource
    # Params: url to fetch data from
    def get_remote_content(url)
      # TODO Add Cache support
      # cachr = Cacher.new
      # remote_content = cachr.fetch(url)
      remote_content = nil
      unless remote_content
        curlr = Curl::Easy.new(url)
        curlr.perform
        remote_content = curlr.body_str
        # cachr.store(url, remote_content)
      end
  
      return remote_content
    end

    # Retrieve the raw source contents for a given module name
    # @method get_raw
    # @param {string} name The module name you wish to fetch the source from
    # @return {string} raw source
    def get_raw(name)
      raise "CURL and/or Caching was not detected, so the content can't be embedded" unless @embed_avail
      return get_remote_content(get_url(name))
    end

    # Retrieve the style or script node with embedded source for a given module name and resource type
    # @method get_content
    # @param {string} name The module name to fetch the source from
    # @param {string} type Resource type (i.e.) YUI_JS or YUI_CSS
    # @return {string} style or script node with embedded source
    def get_content(name, type)
      unless @curl_avail
        return "<!-- CURL was not detected, so the content can't be embedded -->" + get_link(name, type)
      end
  
      url = get_url(name)
      if not url.nil?
        return "<!-- PATH FOR #{name} NOT SPECIFIED -->"
      elsif type.include?(YUI_CSS)
        return '<style type="text/css">' + get_remote_content(url) + '</style>'
      else
        return '<script type="text/javascript">' + get_remote_content(url) + '</script>'; 
      end
    end

    # Retrieve the link or script include for a given module name and resource type
    # @method get_link
    # @param {string} name The module name to fetch the include for
    # @param {string} type Resource type (i.e.) YUI_JS or YUI_CSS
    # @return {string} link or script include
    def get_link(name, type)
      url = get_url(name)
  
      if not url.nil?
        return "<!-- PATH FOR #{name} NOT SPECIFIED -->"
      elsif type.include?(YUI_CSS)
        return "<link rel=\"stylesheet\" href=\"#{url}\" type=\"text/css\" media=\"screen\" charset=\"utf-8\" />"
      else
        return "<script type=\"text/javascript\" charset=\"utf-8\" src=\"#{url}\"></script>"
      end
    end

    # Retrieves the combo link or script include for the currently loaded modules of a specific resource type
    # @method get_combo_link                                                                                       
    # @param {string} type Resource type (i.e.) YUI_JS or YUI_CSS                                                
    # @return {string} link or script include                                                                    
    def get_combo_link(type)
      url = String.new
  
      if type.include?(YUI_CSS)
        unless @css_combo_location.nil?
          url = "<link rel=\"stylesheet\" href=\"#{@css_combo_location}\" type=\"text/css\" media=\"screen\" charset=\"utf-8\" />\n"
        else
          url = "<!-- NO YUI CSS COMPONENTS IDENTIFIED -->"
        end
    
      elsif type.include?(YUI_JS)
        unless @js_combo_location.nil?
          url += "<script type=\"text/javascript\" charset=\"utf-8\" src=\"#{@js_combo_location}\"></script>\n"
        end
      else
        url = "<!-- NO YUI JAVASCRIPT COMPONENTS IDENTIFIED-->"
      end
  
      # allow for raw and debug over minified default
      if @filter
        if not @filter_list.empty? and not @filter_list[name]
          # skip
        elsif @filters[@filter]
          filtr = @filters[@filter]
          url.gsub!(filtr[YUI_SEARCH], filtr[YUI_REPLACE])
        end
      end
  
      return url
    end

    # Adds a module the combo collection for a specified resource type
    # @method addToCombo
    # @param {string} name The module name to add
    # @param {string} type Resource type (i.e.) YUI_JS or YUI_CSS
    def add_to_combo(name, type)
      path_to_module = [@combo_default_version, "/build/", @modules[name][YUI_PATH]].join
      return {"name" => name, "type" => type, "path" => path_to_module}
    end

    # Identifies what module(s) are provided by a given module name (e.g.) yaho-dom-event provides yahoo, dom, and event
    # @method getProvides
    # @param {string} name Module name
    # @return {array}
    def get_provides(name)
      provides = Array.new
      provides << name
      if @modules.has_key?(name) and not @modules[name][YUI_SUPERSEDES].nil?
        @modules[name][YUI_SUPERSEDES].each { |i| provides << i } 
      end
  
      return provides
    end

    def update_cache
      if @full_cache_key
        Rails.cache.write(@full_cache_key, {
          :YUI_MODULES   => @modules,
          :YUI_SKIN      => @skin,
          :YUI_ROLLUP    => @rollup_modules,
          :YUI_GLOBAL    => @global_modules,
          :YUI_DEPCACHE  => @dependencies_cache, 
          :YUI_SATISFIES => @satisfaction_map,
          :YUI_FILTERS   => @filters    
        })
      end
    end

    def load_single(name)
      unless parse_skin(name).nil?
        @skins << name
        @dirty = true
      end

      @undefined_modules[name] = name unless @modules.has_key?(name)

      unless (@loaded.has_key?(name) or @accounted_for.has_key?(name))
        @required_modules[name] = name
        @dirty = true
      end
    end

    def parse_skin(module_name)
      module_name.include?(@skin[YUI_PREFIX]) ? module_name.split('-') : nil
    end

    def format_skin(skin, module_name)
      prefix_skin = @skin[YUI_PREFIX] + skin
      prefix_skin += '-' + module_name unless module_name.nil?
      return prefix_skin
    end

    def set_processed_module_type(module_type = 'ALL')
      @processed_module_types[module_type] = true
    end

    def set_loaded(modules)
      modules.each do |mod|
        unless @modules[mod].empty?
          @loaded[mod] = mod
          get_superseded(mod).each do |name, val|
            @loaded[name] = name
          end
          set_prcessed_module_type(@modules[mod][YUI_TYPE])
        else
          raise "YUI_LOADER: undefined module name provided to set_loaded:\t#{mod}"
        end
      end
    end

    def map_satisfying_module(satisfied, satisfier)
      @satisfaction_map[satisfied] = { satisfier => true }
    end
  end
end

ActionView::Base.send(:include, Yui::LoaderHelper)