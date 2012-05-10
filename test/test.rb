#!/usr/bin/ruby
$:.unshift("#{File.expand_path(File.dirname(__FILE__))}/../lib")
require 'tsm-accounting'

puts "now with junk.lua" 
tsm = TSMAccounting::Database.new('./data/TradeSkillMaster_Accounting.lua')
tsm.to_csv('./accounting.csv')

puts "now with junk.lua"
begin
  tsm = TSMAccounting::Database.new('data/junk.lua')
  tsm.to_csv('./accounting_junk.csv')
rescue RuntimeError => e
  puts "rescueing from: "+e.message
end                        

puts "now with hackerFile.lua"
begin
  tsm = TSMAccounting::Database.new('data/hackerFile.lua')
  tsm.to_csv('./accounting_hacker.csv')
rescue RuntimeError => e
  puts "rescueing from: "+e.message
end