YuiLoader
=========

Yui Loader is a Ruby on Rails port of the [YUI PHP Loader](http://yuilibrary.com/projects/phploader) package created by Chad Auld.
At first this was going to be a Ruby port but during the course of converting the PHP code, it became apparent that a Rails plugin would help enforce some object oriented goodness. What you see now, is a work in progress as this plugin slowly transforms into what will hopefully be nice, lean code.


Example
-------

Controller
----------
`  before_filter :yui_setup
  def yui_setup
    @Y = Yui::Loader.new('2.7.0')
    @Y.load_optional = true
    @Y.combine = true
    @Y.load(["tabview", "grids"])
  end`

View
----

`@Y.tags`

Results
-------

`<link rel="stylesheet" href="http://yui.yahooapis.com/combo?2.7.0/build/reset-fonts-grids/reset-fonts-grids.css"   type="text/css" charset="utf-8" />
<script type="text/javascript" charset="utf-8" src="http://yui.yahooapis.com/combo?2.7.0/build/container/container_core-min.js&2.7.0/build/connection/connection-min.js&2.7.0/build/tabview/tabview-min.js&2.7.0/build/yahoo-dom-event/yahoo-dom-event.js&2.7.0/build/element/element-min.js&2.7.0/build/menu/menu-min.js"></script>`


Copyright (c) 2009 Scott Jungling, released under the BSD license