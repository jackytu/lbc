# coding: UTF-8

module LightBoxClient
  class Protocol
 
    attr_reader :command

    def initialize(command)
      @command = command
    end

    def create_user_protocol
      {
        'email' => command.email,
        'password' => command.password
      }
    end

    def get_token_protocol
      {
        'email' => command.email,
        'password' => command.password
      }
    end
   
    def update_user_protocol
      {
        'password' => command.password,
      }
    end    

    def create_box_protocol
      payload = { 
         'name' => command.name,
         'limits' => {
           'mem' => command.limits[:memory]
         }
      }
      payload.store('batch', command.batch) if command.batch
      payload.store('stack', command.image) if command.image
      payload.store('location', command.location) if command.location
      ports = []
      begin
        if command.ports
          command.ports.split(',').each do |port| 
            ports << Integer(port)
          end
        end
      rescue => e
        puts "Invalid port option given!"
        exit
      end
      payload.store('port', ports)
      payload
    end

    def method_missing(*args)
      {}
    end

  end
end
