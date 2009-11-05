ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + "/../../../.."
require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'action_view'
require 'md5'
# require 'json'
require 'net/http'
require "curb"
require 'ruby-debug'
require 'logger'
require 'test/unit'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

