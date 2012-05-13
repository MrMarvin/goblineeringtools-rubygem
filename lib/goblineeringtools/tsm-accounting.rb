require 'timeout'
require 'csv'
require 'json'
require 'goblineeringtools/safeluaparse.rb'

module Goblineeringtools
  
  module TSMAccounting

    def self.acceptable_fields
      ['Realm','Faction','Realm-Faction','Transaction Type','DateTime',"Date","Time",'Item ID','Item Name','Quantity','Stack Size','Price (g)','Price (c)','Buyer','Seller']
    end    
    
    def self.default_fields
      ['Realm','Faction','Transaction Type','DateTime','Item ID','Item Name','Quantity','Stack Size','Price (g)','Price (c)','Buyer','Seller']
    end

    class Database

      attr_reader :data
      def initialize(path_to_tsm_accounting_file, lua_timeout = 10)

        # use lua to create a json from the savedVars
        database = Goblineeringtools::vars_to_ruby(path_to_tsm_accounting_file,
          "TradeSkillMaster_AccountingDB",
          {:cleanup? => true, :lua_timeout => lua_timeout})
        
        begin
          @data = {}
          faction_data = database["factionrealm"]
          faction_data.keys.each do |auctionhouse|
            faction, realm = auctionhouse.split(" - ")
            @data[realm] = {} unless @data.has_key? realm
            @data[realm][faction] = {} unless @data[realm].has_key? faction
            @data[realm][faction]["sale"] = parse_rope(faction_data[auctionhouse]["itemData"]["sell"],"sale")
            @data[realm][faction]["purchase"] = parse_rope(faction_data[auctionhouse]["itemData"]["buy"],"purchase")
          end   
        rescue
          #raise
          raise RuntimeError, "Invalid database file"
        end
    
      end # initialize

      def to_csv(output_file, field_list=[] )
        # if no fields were specified, use the default
        field_list = Goblineeringtools::TSMAccounting.default_fields if field_list.empty?

        # !!!DANGER!!! only allow known good fields (and not abitrary method calls!)
        raise RuntimeError, "bad field_list!" if not (field_list - Goblineeringtools::TSMAccounting::acceptable_fields).empty?

        CSV.open(output_file, 'w') do |f|
          f << field_list # the headline row

          current_transaction = {}
          @data.each do |realm,factions|
            current_transaction[:realm] = realm
            
            factions.each do |faction,ropes|
              current_transaction[:faction] = faction
              current_transaction[:realmfaction] = realm+" - "+faction
              
              ropes.each do |type,items|
                unless items.nil?
                  items.each do |name,item|
                    item.transactions.each { |tx|
                      row = []
                      # now add the value for every field that was specified in field_list
                      field_list.each do |field_name|

                        # srips space, - and ( ) from the field name and converts it to symbol to use it in send()
                        field_sym = field_name.downcase.gsub(/ |\(|\)|-/,"").to_sym
                        if current_transaction.keys.include? field_sym
                          row << current_transaction[field_sym]
                        elsif field_name =~ /^Item .*/
                          # fields can either begin with "Item", then ask the item object
                          row << item.public_send(field_sym)
                        else
                          # or are values of the transaction object
                          row << tx.public_send(field_sym)
                        end
                        
                      end
                      f << row
                    }
                  end
                end # check for emtpy items end
              end
            end
          end
        end # close CSV
      end # to_csv


      def parse_rope(rope,type)
        unless rope.nil? || rope.empty?
          list = {}
          rope.each_value do |row|
            item = Item.new(row,type)

            if list.has_key? item.name
              # merge
            else
              list[item.name] = item
            end
          end
          list
        end
      
       return list 
      end # parse_rope
      
    end # Database

    class Item
      attr_reader :id, :name, :transactions

      def initialize(item,type)
        encoded_item, encoded_records = item.split '!'

        if encoded_item[0,1] == 'x'
          @id, @name = decode_code(encoded_item)
        else
          @id, @name = decode_link(encoded_item)
        end
        # every actual transaction is seperated by @ in this single line
        @transactions = encoded_records.split('@').map {|record| Transaction.new(record,type) }
        @transactions ||= []
      end # initialize
      
      def itemid
        @id
      end

      def itemname
        @name
      end

      protected 
      def decode_link(text)
        colour, code, name = text.split '|'
      
        # In the case of items with random enchantments (ie
        # Jasper Ring of the Bedrock), the item ID is the same for
        # all rings (52310) but there is an additional attribute
        # seperated by a colon to identify the enchantment.

        id, ench = code.split ':'
        return [TSMAccounting.decode(id), name]
      end # decode_link

      # I _think_ this will only get called if the item link cannot
      # be resolved by TSM for some reason. I am guessing it will
      # store the raw item code (as opposed to, you know, nothing).
      #
      # In theory, this shouldn't get called...
      # if it does however, decode only itemID and leave name blank
      def decode_code(text)
        #strip the x in the biginning!
        text = text[1..-1]
        id, ench = text.split ':'
        return [TSMAccounting.decode(id), ""]
      end # decode_string
    end # item

    class Transaction
      attr_reader :transactiontype, :date, :time, :datetime, :stacksize, :quantity, :datetime, :priceg, :pricec, :buyer, :seller

      def initialize(encoded_string,type)
        # encodes_string is like: B#B#BPkGkK#D0JA#Vohir#Traderjoe
        d = encoded_string.split('#')
        
        @transactiontype = type
        @stacksize = TSMAccounting.decode(d[0])
        @quantity = TSMAccounting.decode(d[1])
        @datetime = Time.at(TSMAccounting.decode(d[2]))
        @pricec = TSMAccounting.decode(d[3])
        if type == 'purchase'
          @buyer = d[5]
          @seller = d[4]
        else
          @buyer = d[4] 
          @seller = d[5] 
        end
        
        @date = @datetime.strftime('%Y-%m-%d')
        @time = @datetime.strftime('%k:%M:%S')
        @datetime = @datetime.strftime('%Y-%m-%d %k:%M:%S')
        @priceg = usable_price 
        
      end # initialize

      def usable_price
        price = @pricec.to_s.rjust(5,'0')
        parts = {
          'gold' => price[0..-5].to_i,
          'silver' => price[-4..2].to_i,
          'copper' => price[-2..2].to_i
        }

        # Round up the copper.
        parts['silver'] += 1 if parts['copper'] > 50

        # If this was a <50c transaction, set silver to 1 so
        # it doesn't confuse people.
        if parts['gold'] == 0 and parts['silver'] == 0 and parts['copper'] < 50
          parts['silver'] = 1
        end
      
        return "#{parts['gold']}.#{parts['silver']}".to_f
      end

    end # Transaction

    def self.decode(value)
      alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_="
      base = alpha.length

      i = value.length - 1
      result = 0
      value.each_char do |w|
        if w.match(/([A-Za-z0-9_=])/)
          result += (alpha.index(w)) * (base**i)
          i -= 1
        end
      end

      return result
    end # decode
    
  end # TSMAccounting
end