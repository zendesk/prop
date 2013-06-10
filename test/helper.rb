require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'time'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'prop'

class Test::Unit::TestCase
end
