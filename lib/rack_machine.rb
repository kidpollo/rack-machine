require "rubygems"
require "bundler"
Bundler.setup(:default)

module RackMachine
  unless const_defined?(:VERSION)
    VERSION = '0.0.1'
  end
end

require 'rack_machine/server'