require 'rubygems'
require 'action_view'
require 'md5'
require 'net/http'
require "curl"
require 'ruby-debug'
require 'logger'

module Yui
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
  
  module LoaderHelper

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
  
  
  class Loader
    # base      (string) Allows you to specify a different location (as a full
    #   or relative filepath) for the YUI build directory. By default, YUI PHP
    #   Loader will serve files from Yahoo's servers.
    # 
    # filter   (string) A filter to apply to result urls. This filter will
    #   modify the default path for all modules. The default path for the YUI
    #   library is the minified version of the files (e.g., event-min.js). The
    #   valid filters are:
    #     YUI_DEBUG
    #       Selects the debug versions of the library (e.g., event-debug.js).
    #       This option will automatically include the logger widget
    #     YUI_RAW
    #       Selects the non-minified version of the library (e.g., event.js).
    # 
    # allowRollups  (boolean) Should Loader use aggregate files (like
    #   yahoo-dom-event.js or utilities.js) that combine several YUI
    #   components in a single HTTP request? Default: true.
    # 
    # loadOptional  (boolean) Should loader load optional dependencies for the
    #   components you're requesting? (Note: If you only want some but not all
    #   optional dependencies, you can list out the dependencies you want as
    #   part of your required list.) Default: false.
      
    # combine (boolean) If set to true, YUI files will be combined into a
    #   single request using the combo service provided on the Yahoo! CDN
    # 
    # comboBase  (string) The base path to the Yahoo! CDN service. 
    #   Default: "http://yui.yahooapis.com/combo? 
    # 

    # attr_accessor :base, :combo_base, :filter, :target, :combine, :allow_rollups, :load_optional, :rollups_to_top, :processed_module_types, :requests, :loaded, :superseded, :undefined, :dirty, :sorted, :accounted_for, :filter_list, :skins, :modules, :full_cache_key, :base_overrides, :cache_found, :delay_cache, :version, :version_key, :skin, :rollup_modules, :global_modules, :satisfaction_map, :dep_cache, :filters, :css_combo_location, :js_combo_location, :yui_current, :combo_default_version, :cache_avail, :curl_avail, :json_avail, :embed_avail, :logger

    attr_accessor :load_optional, :combine, :combine_base, :allow_rollups, :base, :filter
    def initialize(yui_version, cache_key = nil, modules = nil, no_yui = false)

      # Combined into a single request using the combo service to potentially reduce the number of http requests required
      @combine = true

      # Should we allow rollups
      @allow_rollups = true

      # Whether or not to load optional dependencies
      @load_optional = false

      # Force rollup modules 
      @rollups_to_top = false

      # keeps track of modules
      @processed_module_types = Hash.new
      
      # all required modules
      @requests = Hash.new
      
      # Modules that have been outputted via getLink
      @loaded = Hash.new
      
      # list of all modules superseded by the list of required modiles
      @superseded = Hash.new
      
      # track undefined modules
      @undefined = Hash.new

      @dirty = true

      @sorted = Array.new

      @accounted_for = Hash.new

      # A list of modules to apply the filter to.
      @filter_list = nil

      # required skins
      @skins = Array.new

      @modules = Hash.new

      @full_cache_key = nil

      @base_overrides = Hash.new

      @cache_found = false

      @delay_cache = false

      # cache busting hack for environs that use same path for current vers of lib
      @version = nil

      @version_key = "_yuiversion"

      @skin = Hash.new
          
      @rollup_modules = Hash.new
      
      @global_modules = Hash.new
      
      @satisfaction_map = Hash.new
      
      @dep_cache = Hash.new
      
      @filters = Hash.new

      # base path to combo service
      @combo_base = "http://yui.yahooapis.com/combo?"

      # # additional vars used to assist with combo handling
      # @css_combo_location = nil
      # 
      # @js_combo_location = nil
      # @yui_current = Array.new

      unless yui_version
        raise "Error: the first parameter of YAHOO_util_loader must specify which version of YUI to use"
      end
    
      json_config_file = [File.dirname(__FILE__),"/../" , '/meta/json_', yui_version, '.txt'].join()

      if (File.exist?(json_config_file))
        @yui_current = ActiveSupport::JSON.decode(File.read(json_config_file))
      else
        raise "Unable to find a suitable YUI metadata file!"
      end

      @cache_avail           = ActionController::Base.cache_configured?
      @curl_avail            = Curl::Easy.methods.include?('http_get')
      @json_avail            = Rails.methods.include?('to_json')
      @embed_avail           = (@curl_avail and @cache_avail)
      @base                  = @yui_current[YUI_BASE]
      @combo_default_version = yui_version


      if @cache_key and @cache_avail
        @full_cache_key = MD5.hexdigest(@base + @cache_key)
        @cache = Rails.cache.read(@full_cache_key)
        unless @cache.nil?
          @cache_found      = true
          @modules          = cache[YUI_MODULES]
          @skin             = cache[YUI_SKIN]
          @rollup_modules   = cache[YUI_ROLLUP]
          @global_modules   = cache[YUI_GLOBAL]
          @satisfaction_map = cache[YUI_SATISFIES]
          @dep_cache        = cache[YUI_DEPCACHE]
          @filters          = cache[YUI_FILTERS]
        end
      end

      @modules = no_yui ? Hash.new : @yui_current['moduleInfo']

      # merge modules if we have some custom modules
      @modules.merge!(modules.to_hash) unless modules.nil?
      @skin = @yui_current[YUI_SKIN]
      @skin['overrides'] = Hash.new
      @skin[YUI_PREFIX] = 'skin-'

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

      @modules.each do |name, mod|
        @global_modules[name] = true if mod[YUI_GLOBAL]
        if mod[YUI_SUPERSEDES]
          @rollup_modules[name] = mod
          mod[YUI_SUPERSEDES].each {|sup| map_satisfying_module(sup,name)}
        end
      end
    end

    # Used to load YUI and/or custom components
    # params array of components
    def load(components = nil)
      raise "Components must be defined in an array" if components.nil?
      components.each { |c| load_single(c)}
    end
    

    def tags(module_type = nil, skip_sort = false)
      dependencies = process_dependencies(YUI_TAGS, module_type, skip_sort)
      css = []
      js = []
      dependencies.each do |d| 
        css << d if d.values.first['type'].include?(YUI_CSS)
        js << d  if d.values.first['type'].include?(YUI_JS)
      end
      css.flatten!
      js.flatten!
      html = String.new 
      html += get_stylesheet_tag(css)
      html += get_javascript_tag(js)
      return html
    end

    def get_javascript_tag(mods)
      html = String.new
      combo = []
      
      if @combine 
        mods.each do |m|
          m.each do |name, attributes|
            combo << attributes['path']
          end
        end
        html += '<script type="text/javascript" charset="utf-8" src="' + @combo_base + combo.join("&") + '"></script>' + "\n"
      else
        mods.each do |m|
          m.each do |name, attributes|
            html += '<script type="text/javascript" charset="utf-8" src="' + @combo_base + attributes['path'] + '"></script>' + "\n"
          end
        end
      end
      return html
    end

    def get_stylesheet_tag(mods)
      html = String.new
      combo = []

      if @combine
        mods.each do |m|
          m.each do |name, attributes|
            combo << attributes['path']
          end
        end
        html += '<link rel="stylesheet" href="'+ @combo_base + combo.join("&") + '" type="text/css" charset="utf-8" />' + "\n"
      else
        mods.each do |m|
          m.each do |name, attributes|
            html += '<link rel="stylesheet" href="'+ @combo_base + attributes['path'] + '" type="text/css" charset="utf-8" />' + "\n"
          end
        end
      end
      
      return html
    end
    
    protected
  
    def account_for(name)
      @accounted_for[name] = name
      if @modules.has_key?(name)
        get_superseded(name).each do |supname, val|
          @accounted_for[supname] = true
        end
      end
    end

    def prune(dependencies, module_type)
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
  
    def get_superseded(name)
      key = YUI_SUPERSEDES + name
      sups = Hash.new
      return @dep_cache[key] if @dep_cache[key]

      if @modules.has_key?(name)
        unless @modules[name][YUI_SUPERSEDES].nil?
          @modules[name][YUI_SUPERSEDES].each  do |sup_name|
            sups[sup_name] = true
            sups.merge!(@get_superseded[sup_name]) if @modules[sup_name]
          end
        end
      end

      @dep_cache[key] = sups
      return sups
    end
  
    def skin_setup(name)
      skin_name = nil
      dep = @modules[name]
  
      if dep and dep[YUI_SKINNABLE]
        s = @skin
    
        if not s[YUI_OVERRIDES].empty? and s[YUI_OVERRIDES][name]
          s[YUI_OVERRIDES][name].each do |name, over|
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
          path = "#{package}/#{s[YUI_BASE]}#{skin[1]}/#{skin[2]}.css"
          @modules[skin_name] = {
            "name"  => skin_name, 
            "type"  => YUI_CSS,
            "path"  => path, 
            "after" => s[YUI_AFTER]  
          }
        else
          path = "#{s[YUI_BASE]}#{s[1]}/#{s[YUI_PATH]}"
          new_mod = {
            "name"   => skin_name,
            "type"   => YUI_CSS,
            "path"   => path, 
            "rollup" => 3,
            "after"  => s[YUI_AFTER]    
          }
          @modules[skin_name] = new_mod
          @rollup_modules[skin_name] = new_mod
        end
      end
      return  skin_name
    end
  
    def get_all_dependencies(module_name, load_optional = false, completed = {})
      key = [YUI_REQUIRES, module_name].join
      key += YUI_OPTIONAL if load_optional
  
      return @dep_cache[key] if @dep_cache[key]
  
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
        else
          # TODO: log error
        end
      end
  
      @dep_cache[key] = requires
      return requires
    end
  
    def get_global_dependencies(module_type = nil)
      return @global_modules
    end
  
    # Returns true if the supplied satisfied module is satisfied by the supplied satisfier module
    def module_satisfies?(satisfied, satisfier)
      satisfied.include?(satisfier) or (@satisfaction_map.has_key?(satisfied) and @satisfaction_map[satisfied][satisfier])
    end
  
    # Used to override the base directory for specific set of modules (Not supported with combo service)
    # Params: base, modules
    def override_base(base, modules)
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
      requires     = {}
      top      = {}
      bot      = {}
      not_done = {}
      sorted   = {}
      found    = {}
  
      # add global dependenices so they are included when calculating rollups
      globals = get_global_dependencies(module_type)
  
      globals.each { |name, dep| requires[name] = true }
  
      # get and store the full list of dependencies
      @requests.each do |name, val|
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
      # 
      # if (module_type.nil? and not output_type.include?(YUI_JSON) and not output_type.include?(YUI_DATA))
      #   @delay_cache = true
      #   css = process_dependencies(output_type, YUI_CSS, skip_sort, show_loaded)
      #   js = process_dependencies(output_type, YUI_JS, skip_sort, show_loaded)
      #   @update_cache unless @cache_found
      #   return css + js
      # end
      if show_loaded or (not @dirty and not @sorted.empty?)
        sorted = prune(@sorted, module_type)
      else
        sorted = sort_dependencies(module_type, skip_sort)
      end
      foo = []
      sorted.each do |name, val|
        if show_loaded or not @loaded[name]
          dep = @modules[name]
          foo << add_to_combo(name, dep[YUI_TYPE])
          # case output_type
          # when YUI_EMBED
          #   html += get_content(name, dep[YUI_TYPE]) + "\n"
          #   when YUI_RAW
          #   html += get_raw(name) + "\n"
          #   when YUI_DATA
          #   json[dep[YUI_TYPE]] = { get_url(name) => get_provides(name) }
          #   when YUI_FULLJSON
          #   json[dep[YUI_NAME]] = {
          #     YUI_TYPE     => dep[YUI_TYPE], 
          #     YUI_URL      => get_url(name), 
          #     YUI_PROVIDES => get_provides(name), 
          #     YUI_REQUIRES => dep[YUI_REQUIRES], 
          #     YUI_OPTIONAL => dep[YUI_OPTIONAL]
          #   }
          #   else
          #     if @combine
          #       add_to_combo(name, dep[YUI_TYPE])
          #       html = get_combo_link(dep[YUI_TYPE])
          #     else
          #       html += get_link(name, dep[YUI_TYPE]) + "\n"
          #     end
          # end
        end
      end
  
      # if the data has not been cached, and we are not running two rotations for separating css and js, cache what we have
      @update_cache if (@cache_avail and @cache_found and @delay_cache)
  
      # # logger.info(json.inspect)
      # unless json.empty?
      #   if @json_avail
      #     html += json.to_json
      #   else
      #     html += "<!-- JSON not available, request failed -->"
      #   end
      # end
      #   
      # after the first pass we no longer try to use meta modules
      set_processed_module_type(module_type)
  
      # keep track of all the stuff that we loaded so that we don't reload
      # script if the page makes multiple calls to tags
      @loaded.merge!(sorted)
  
      # # return the raw data structure
      # if output_type.include?(YUI_DATA)
      #   return json 
      # elsif not @undefined.empty?
      #   html += "<!-- The following modules were requested but are not defined: #{@undefined.join(", ")} -->"
      # end
      # puts "process dep end\t#{module_type}\n\t#{html}\n"
      # puts "\n\tFinal foo #{foo.inspect}"
      return foo
      # return html
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

    def get_raw(name)
      raise "CURL and/or Caching was not detected, so the content can't be embedded" unless @embed_avail
      return get_remote_content(get_url(name))
    end

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

    def add_to_combo(name, type)
      # logger.info("add to combo #{name} of type #{type}")
      path_to_module = [@combo_default_version, "/build/", @modules[name][YUI_PATH]].join
      return {name => {"type" => type, "path" => path_to_module}}
      # if type.include?(YUI_CSS)
      #   if @css_combo_location.nil?
      #     @css_combo_location = [@combo_base,path_to_module].join
      #   else
      #     @css_combo_location += "&amp;" + path_to_module
      #   end
      # else
      #   if @js_combo_location.nil?
      #     @js_combo_location = [@combo_base, path_to_module].join
      #   else
      #     # logger.info("js append \n\t#{path_to_module} to \n\t#{@js_combo_location}")
      #     @js_combo_location += "&amp;" + path_to_module
      #   end
      # end
    end

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
          :YUI_DEPCACHE  => @dep_cache, 
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

      @undefined[name] = name unless @modules.has_key?(name)

      unless (@loaded.has_key?(name) or @accounted_for.has_key?(name))
        @requests[name] = name
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