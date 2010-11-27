require "rubygems"
require "bundler"
Bundler.setup(:test)

require 'rack_machine'
require 'rspec'

Rspec.configure do |c|
  c.mock_with :rspec
end