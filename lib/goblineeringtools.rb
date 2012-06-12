dir = File.expand_path('../lib/goblineeringtools/', __FILE__)
$:.unshift dir unless $:.include?(dir)

require 'goblineeringtools/safeluaparse'
require 'goblineeringtools/tsm-accounting'
require 'goblineeringtools/tsm-itemtracker'