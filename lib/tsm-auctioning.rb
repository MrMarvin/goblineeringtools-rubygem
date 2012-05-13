require 'timeout'
require 'csv'
require 'json'

module Goblineeringtools
  
  module TSMAuctioning

    class Category

      def to_csv(output_file)
        CSV.open(output_file, 'w') do |f|
          f << ['Realm','Faction','Transaction Type','Time','Item ID','Item Name','Quantity','Stack Size','Price (g)','Price (c)','Buyer','Seller']
          @data.each do |realm,factions|
            factions.each do |faction,ropes|
              ropes.each do |type,items|
                unless items.nil?
                  items.each do |name,item|
                    item.transactions.each do |tx|
                      row = [realm,faction,type] 
                      row << tx.datetime.strftime('%Y-%m-%d %k:%M:%S')
                      row << item.id
                      row << item.name
                      row << tx.quantity
                      row << tx.stack_size
                      row << tx.usable_price
                      row << tx.price
                      row << tx.buyer
                      row << tx.seller
                      f << row
                    end
                  end
                end # check for emtpy items end                 
              end                           
            end                 
          end 
        end # close CSV   
      end # to_csv        

    end # Category

    class Group

      def to_csv(output_file)
        
      end

    end # Group
  
  end # TSMAuctioning
  
end # Goblineeringtools