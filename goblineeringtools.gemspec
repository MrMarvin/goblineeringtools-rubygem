lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'goblineeringtools'

Gem::Specification.new do |s|
  s.name        = "goblineeringtools"
  s.version     = "0.42.3"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["owlmanatt","margi"]
  s.email       = ["owlmanatt@gmail.com","marv@hostin.is"]
  s.homepage    = "https://github.com/MrMarvin/goblineeringtools-rubygem"
  s.summary     = "Rubygem for accessing your TSM savedvariable files and other gonblineering tricks."
  s.description = "time is money, friend"
  s.required_rubygems_version = ">= 1.3.6"
  s.required_ruby_version = '>= 1.9.3'

  s.files        = Dir.glob("{lib}/**/*") + Dir.glob("{test/**/*}") + %w(AUTHORS HISTORY LICENSE README)
  s.require_path = 'lib'
end
