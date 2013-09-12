require 'rubygems'

require "minitest/spec"
require "minitest/mock"
require "minitest/autorun"
require 'mocha/setup'

require 'time'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'prop'
