require 'timeout'
require 'csv'
require 'json'

module Goblineeringtools
  
  module TSMAuctioning

    # generates an Array of Categories and one empty categrory for Groups without any
    def self.from_file(path_to_tsm_auctioning_file, lua_timeout = 10)
      
      data = Goblineeringtools::vars_to_ruby(path_to_tsm_auctioning_file,
        "TradeSkillMaster_AccountingDB", {:cleanup? => true, :lua_timeout => lua_timeout})
      
      
    end

    class Category
      
      def initialize

      end

    end # Category

    class Group

      def initialize

      end

    end # Group
  
  end # TSMAuctioning
  
end # Goblineeringtools