#!/usr/bin/ruby
$:.unshift("#{File.expand_path(File.dirname(__FILE__))}/../lib")
require 'safeluaparse'
require 'tsm-accounting'
require 'tsm-auctioning'

puts "now with TradeSkillMaster_Accounting.lua" 
tsm = Goblineeringtools::TSMAccounting::Database.new('./data/TradeSkillMaster_Accounting.lua')
tsm.to_csv('./accounting.csv')

puts "now with TradeSkillMaster_Accounting.lua and other fields" 
tsm = Goblineeringtools::TSMAccounting::Database.new('./data/TradeSkillMaster_Accounting.lua')
tsm.to_csv('./accounting_fewfields.csv',["Date","Time",'Item ID','Item Name','Price (g)','Buyer'])


puts "now with junk.lua"
begin
  tsm = Goblineeringtools::TSMAccounting::Database.new('data/junk.lua')
  tsm.to_csv('./accounting_junk.csv')
rescue RuntimeError => e
  puts "rescueing from: "+e.message
end                        

puts "now with hackerFile.lua"
begin
  tsm = Goblineeringtools::TSMAccounting::Database.new('data/hackerFile.lua')
  tsm.to_csv('./accounting_hacker.csv')
rescue RuntimeError => e
  puts "rescueing from: "+e.message
end