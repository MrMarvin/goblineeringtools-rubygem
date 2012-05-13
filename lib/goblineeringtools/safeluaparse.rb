require 'timeout'
require 'json'

module Goblineeringtools

  def self.vars_to_ruby(path_to_file, root_var_name, opts = {})
      opts = {:lua_timeout => 5, :cleanup? => true, :indent? => false}.merge!(opts)
      cmd_string = "lua -e \"json = require('dkjson');
      local sec_env = {};
      local script = loadstring(io.open('#{path_to_file}','r'):read('*all'));
      setfenv(script, sec_env);
      pcall(script);
      io.open('#{path_to_file}'..'.json','w'):write(
        json.encode(sec_env.#{root_var_name}, { indent = #{opts[:indent?].to_s} }));\""
    
      begin
        Timeout.timeout(opts[:lua_timeout]) do
        # trying to redirect STDERR, but nothing happens (ruby 1.9.3)...
        #@lua_pipe = IO.popen(lua_string, :err => File.open("/dev/null","w"))
          @lua_pipe = IO.popen(cmd_string)
          Process.wait @lua_pipe.pid
        end
      rescue Timeout::Error
         Process.kill 9, @lua_pipe.pid
       
         # raise up to our consumer
         raise
      end
       
       # then load the json cause its so easy and nice
       begin
         json_string = File.open(path_to_file+'.json').read
         data = JSON::parse(json_string)
       rescue Exception
         
       ensure
         # clean up the temp file!
         if File.exists?(path_to_file+'.json') and opts[:cleanup?]
           File.delete(path_to_file+'.json')
         end 
       end
       
       data
  end #vars_to_ruby
end