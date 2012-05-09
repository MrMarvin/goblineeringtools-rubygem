# Copyright (c) 2011, Nicholas 'OwlManAtt' Evans <owlmanatt@gmail.com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice, this
#     list of conditions and the following disclaimer.
# 
#   * Redistributions in binary form must reproduce the above copyright notice, 
#     this list of conditions and the following disclaimer in the documentation 
#     and/or other materials provided with the distribution.
# 
#   * Neither the name of the Yasashii Syndicate nor the names of its contributors 
#     may be used to endorse or promote products derived from this software 
#     without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
require 'csv'
require 'json'

module TSMAccounting
  VERSION = '1.2.0'

  class Database
    class InvalidDatabaseFileException < RuntimeError
    end

    attr_reader :data
    # Expects the whole TradeSkillMaster_Accounting.lua file
    # as a string.
    def initialize(path_to_tsm_accounting_file)

	
      # shell out and run lua to parse the file and print it as json
	  json_string = `lua -e "json = require('dkjson');
	  local sec_env = {};
	  local script = loadstring(io.open('#{path_to_tsm_accounting_file}','r'):read('*all'));
	  setfenv(script, sec_env);
	  pcall(script);
	  print(json.encode(sec_env.TradeSkillMaster_AccountingDB, { indent = true }));"`
	  # then load the json cause its so easy and nice
	  database = JSON::parse(json_string)

	@data = {}
	  faction_data = database["factionrealm"]
      faction_data.keys.each do |auctionhouse|
		faction, realm = auctionhouse.split(" - ")
		@data[realm] = {} unless @data.has_key? realm
		@data[realm][faction] = {} unless @data[realm].has_key? faction
	    @data[realm][faction]["sale"] = parse_rope(faction_data[auctionhouse]["itemData"]["sell"],"sale")
		@data[realm][faction]["purchase"] = parse_rope(faction_data[auctionhouse]["itemData"]["buy"],"purchase")
	  end

    end # initialize

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
	# strip the x in the biginning!
	  text = text[1..-1]	  
	  id, ench = text.split ':'
      return [TSMAccounting.decode(id), ""]
    end # decode_string
  end # item

  class Transaction
    attr_reader :stack_size, :quantity, :datetime, :price, :buyer, :seller

    def initialize(encoded_string,type)
      d = encoded_string.split('#')

      @stack_size = TSMAccounting.decode(d[0])
      @quantity = TSMAccounting.decode(d[1])
      @datetime = Time.at(TSMAccounting.decode(d[2]))
      @price = TSMAccounting.decode(d[3])
      if type == 'purchase'
        @buyer = d[5]
        @seller = d[4]
      else
        @buyer = d[4] 
        @seller = d[5] 
      end
    end # initialize

    def usable_price
      price = @price.to_s.rjust(5,'0')
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