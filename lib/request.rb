# coding: UTF-8

require "error"
require "awesome_print"

module LightBoxClient
  class Request
    MAX_RETRIES = 10
    REQUEST_INTERVAL = 0.2
    BASIC_HEAD = {
      'content-type' => 'application/json'
    }
    BASIC_TIMEOUT = {
      :connect_timeout => 10,
      :inactivity_timeout => 10
    }

    attr_reader :command
    attr_accessor :method
    attr_accessor :lightbox
    attr_accessor :api
    attr_accessor :started
    attr_accessor :payload
 
    def initialize(command)
      @command = command
      if command.lightbox
        fh = File.open("#{LightBoxClient::WORKSPACE}/server", 'w')
        fh.puts command.lightbox
        fh.close
      end

      if command.need_token
         BASIC_HEAD.store('auth', command.token)
      end

      @payload = command.payload
      @api = standard_api(command.api)
      @method = command.method
      @lightbox = command.lightbox
      @started = Time.now
    end
 
    def lightbox_uri(raw_api)
      lightbox + '/' + raw_api
    end
 
    def standard_api(uri)
      pattern = /\<(\w+)\>/i
      ret = uri.scan(pattern)
      if ret.size > 0
        ret.each do |var|
          uri.gsub!(var[0], command.send(var[0]))
        end
        uri.gsub!('<','').gsub!('>','')
      end
      uri
    end

    def start(&blk)
       puts "[#{Time.now}] Starting #{command.command} with options: ".colorize(:green)
       ap command.payload, {:index => false, :indent => 4}
       started = Time.now 
       request_with_retry(api, payload.to_json, method, nil, 0 )
    end

    def cache_token(token)
      fh = File.open("#{LightBoxClient::WORKSPACE}/token", 'w')
      fh.puts token
      fh.close      
    end

    def ap_succ_resp(resp)
       puts "[#{Time.now}] LightBox completed this request with response:".colorize(:green)
       ap resp, :indent => 2, :index => false
       p 
       puts "[Time Costs] :  #{Time.now.to_i - started.to_i} seconds.".colorize(:green)
    end
    
    def ap_fail_resp(resp)
       puts "[#{Time.now}] Sorry, Lightbox error, please try again later.".colorize(:red)
       ap resp 
       puts "[Time Costs] :  #{Time.now.to_i - started.to_i} seconds.".colorize(:green)
    end

    def request_with_retry(raw_api, payload, method, condition, retries = 0 )
      #http = EventMachine::HttpRequest.new(lightbox_uri(raw_api), BASIC_TIMEOUT).send(
      http = EventMachine::HttpRequest.new(lightbox_uri(raw_api)).send(
                  method, 
                  {
                    :head => BASIC_HEAD,
                    :body => payload
                  }
           )
   
      http.callback {
        begin
          resp = Yajl::Parser.parse(http.response)
          if resp
            cache_token(resp['description']["token"]) if resp['description']["token"]
            if resp['description']['redirect']
               redirect_api = resp['description']['redirect']
               method = resp['description']['method'] 
               condition = resp['description']['condition']
               EM.add_timer(REQUEST_INTERVAL) do
                   request_with_retry(redirect_api, {}, method, condition, retries+=1)
               end
            else
              if condition 
                 condition_key = condition.keys[0]
                 condition_value = condition[condition_key]
                 puts "<Expect>: #{condition_key} : #{condition[condition_key]}".colorize(:green) 
                 puts "<Current>:  #{resp['description'][condition_key]}".colorize(:yellow)

                 if resp['success'] && resp['description'][condition_key] == condition_value
                    resp['description'].delete('success') if resp['description']['success']
                    ap_succ_resp(resp)
                    EM.stop
                 else
                    if retries < MAX_RETRIES
                      puts "[#{Time.now}] Still working.".colorize(:green)
                      EM.add_timer(2) do
                        request_with_retry(raw_api, {}, method, condition, retries+=1)
                      end
                    else
                      ap_fail_resp(resp)
                      EM.stop
                    end                   
                 end
              else
                 if resp['success']
                    resp['description'].delete('success') if resp['description']['success']
                    ap_succ_resp(resp)
                    EM.stop
                 else
                    ap_fail_resp(resp)
                    EM.stop
                 end
              end
            end
          else
            puts "Fanally failed without response.".colorize(:red)
            ap resp, :index => false, :indent => 2
            EM.stop
          end
        rescue => e
          puts "API request failed with #{e}.".colorize(:red)
          ap http.response, :index => false, :indent => 2
          EM.stop
        end
      }

      http.errback {
          puts "Error occurred: #{http.error}".colorize(:red)
          EM.stop
          #raise LightBoxClient::Error::CONNECTION_ERROR
      } 
    end 
  end
end  
