require 'timeout'
require 'csv'
require 'json'
require 'goblineeringtools/safeluaparse.rb'

module Goblineeringtools

  module TSMItemtracker


    def self.acceptable_fields
      ['Realm','Faction','Realm-Faction','Item ID','Item Name','Count','Char or Guildbank','Storage Name','Storage Type']
    end

    def self.default_fields
      ['Realm','Faction','Item ID','Count','Char or Guildbank','Storage Name','Storage Type']
    end

    class Database

      attr_reader :data
      def initialize(path_to_tsm_itemtracker_file, lua_timeout = 5)

        # use lua to create a json from the savedVars
        database = Goblineeringtools::vars_to_ruby(path_to_tsm_itemtracker_file,
                                                   "TradeSkillMaster_ItemTrackerDB",
                                                   {:cleanup? => true, :lua_timeout => lua_timeout})

        begin
          @items = Hash.new { |hash, key| hash[key] = Array.new }

          faction_data = database["factionrealm"]
          faction_data.keys.each do |factionminusrealm|
            faction, realm = factionminusrealm.split(" - ")

            faction_data[factionminusrealm]["characters"].each do |charname,chardata|
              chardata.each do |k,v|
                if k=="bags" || k=="bank" # maybe later: auctions as well
                  v.each do |itemid, count|
                    @items[itemid] << Item.new(
                        {
                          :realm => realm,
                          :faction => faction,
                          :charorguildbank => "character",
                          :storagename => charname,
                          :storagetype => k # "bank" or "bags"
                        },
                        count
                      )
                  end
                end
              end
            end

            if faction_data[factionminusrealm].keys.include?("guilds")
              faction_data[factionminusrealm]["guilds"].each do |guildname,guilddata|
                guilddata["items"].each do |itemid, count|
                  @items[itemid] << Item.new(
                      {
                          :realm => realm,
                          :faction => faction,
                          :charorguildbank => "guildbank",
                          :storagename => guildname,
                          :storagetype => "bank"
                      },
                      count
                  )
                end
              end
            end

          end
        rescue
          #raise
          raise RuntimeError, "Invalid database file"
        end
      end

      def to_csv(output_file, field_list=[] )
        # if no fields were specified, use the default
        field_list = Goblineeringtools::TSMItemtracker.default_fields if field_list.empty?

        # !!!DANGER!!! only allow known good fields (and not abitrary method calls!)
        raise RuntimeError, "bad field_list!" if not (field_list - Goblineeringtools::TSMItemtracker::acceptable_fields).empty?

        CSV.open(output_file, 'w') do |f|
          f << field_list # the headline row

          @items.each do |itemid,itemarray|
            itemarray.each do |item|
              row = []
              # now add the value for every field that was specified in field_list
              field_list.each do |field_name|

                # strips space, - and ( ) from the field name and converts it to symbol to use it in send()
                field_sym = field_name.downcase.gsub(/ |\(|\)|-/,"").to_sym

                if field_sym == :itemid
                  row << itemid
                elsif item.storage.keys.include? field_sym
                  row << item.storage[field_sym]
                else
                  row << item.public_send(field_sym)
                end

              end
              f << row

            end
          end

        end # close CSV
      end # to_csv

    end # Database

    class Item

      attr_accessor :storage, :name, :count

      def initialize(storage = {:realm =>nil,:faction =>nil, :charorguildbank=>nil,:storagename=>nil, :storagetype=>nil},count=1,name=nil)

        @storage = storage
        @name = name
        @count = count
      end

      def realmfaction
        @storage[:realm]+" - "+@storage[:faction]
      end

      def itemname
        @name || "not yet implemented"
      end

    end



  end # TSMItemtracker

end # Goblineeringtools