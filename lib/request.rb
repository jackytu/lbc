# coding: UTF-8
require "error"
require "awesome_print"

module LightBoxClient
  #Cache Token
  class CacheError < StandardError; end

  #Lbc Error
  class LbcError < StandardError
    def initialize(message)
      super(message)
    end
  end

  #API request error
  class ApiRequestError < StandardError; end

  #Colorize Error
  class ColorizeError < StandardError; end

  class Request

    MAX_RETRIES = 10
    REQUEST_INTERVAL = 0.2

    BASIC_HEAD = {
      'content-type' => 'application/json'
    }

    BASIC_TIMEOUT = {
      'connect_timeout' => 10,
      'inactivity_timeout' => 10
    }

    attr_reader :command
    attr_accessor :method
    attr_accessor :lightbox
    attr_accessor :api
    attr_accessor :started
    attr_accessor :payload
    
    def initialize(command)
      @command = command
      cache_data(command.lightbox, 'server') if command.lightbox

      if command.need_token
         BASIC_HEAD.store('auth', command.token)
      end

      @payload = command.payload
      @api = standard_api(command.api)
      @method = command.method
      @lightbox = command.lightbox
      @started = Time.now
    end
 
    #Cache the server uri to local file
    #@param [String] data: data to cache
    #@param [String] file: file for cache
    def cache_data(data, file)
      begin
        fh = File.open("#{LightBoxClient::WORKSPACE}/#{file}", 'w')
        fh.puts data
      rescue LightBoxClient::CacheError => e
        raise LightBoxClient::LbcError.new("Cache data failed with exception #{e}")
      ensure
        fh.close
      end
    end

    #Puts message with color
    #@param [String] color: the color will be msg like
    #@param [String] msg: the msg to be puts
    def puts_with_color(color, msg)    
      begin
        puts msg.colorize(color.to_sym)
      rescue ColorizeError => e
        raise LightBoxClient::LbcError.new("Pring msg with color with exception #{e}")
      end
    end

    #Combine the lightbox uri
    #@param [String] raw_api: raw request api for lightbox server
    def lightbox_uri(raw_api)
      lightbox + '/' + raw_api
    end
 
    #Get the standard api, replace <pattern> with real value
    #@param [String] uri: uri to convert
    def standard_api(uri)
      return '' unless uri

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

    #Start the request
    #@param [Block] &blk: Add block here in case hook is needed.
    def start(&blk)
       puts_with_color('green', "[#{Time.now}] Starting #{command.command} with options: ")
       ap command.payload, {:index => false, :indent => 4}
       started = Time.now 
       request_with_retry(api, payload.to_json, method, nil, 0 )
    end

    #Awesome print success response
    #@param [Hash] resp: raw response.
    def ap_succ_resp(resp)
       puts_with_color('green', "[#{Time.now}] LightBox completed this request with response:")
       ap resp, :indent => 2, :index => false
       p 
       puts_with_color('green', "[Time Costs] :  #{Time.now.to_i - started.to_i} seconds.")
    end
    
    #Awesome print failed response
    #@param [Hash] resp: raw response.
    def ap_fail_resp(resp)
       puts_with_color('red', "[#{Time.now}] Sorry, Lightbox error, please try again later.")
       ap resp 
       puts_with_color('green', "[Time Costs] :  #{Time.now.to_i - started.to_i} seconds.")
    end

    #Request lightbox server with retry.
    #@param [String] raw_api: lightbox api.
    #@param [Json] payload: request payload.
    #@param [String] method: request method.
    #@param [String] condition: success condition.
    #@param [Integer] retries: retry times.
    def request_with_retry(raw_api, payload, method, condition, retries = 0 )
      http = EventMachine::HttpRequest.new(lightbox_uri(raw_api)).send(
                  method, 
                  {
                    :head=> BASIC_HEAD,
                    :body => payload
                  }
           )
      http.callback {
        begin
          resp = Yajl::Parser.parse(http.response)
        rescue ParserError => e
          puts_with_color('red', "Parse Json with exception #{LightBoxClient::LbcError.new(e)}.")
          ap http.response, :index => false, :indent => 2
          EM.stop
        end 
       
        if resp && resp['description']
          cache_data(resp['description']["token"], 'token') if resp['description']["token"]

          if resp['description']['redirect']
            redirect_api = resp['description']['redirect']
            method = resp['description']['method'] 
            condition = resp['description']['condition']
            EM.add_timer(REQUEST_INTERVAL) do
              request_with_retry(redirect_api, {}, method, condition, retries+=1)
            end
          else
            if condition && condition.class == Hash 
              condition_key = condition.keys[0]
              condition_value = condition[condition_key]
              puts_with_color('green', "<Expect>: #{condition_key} : #{condition[condition_key]}")
              puts_with_color('yellow', "<Current>:  #{resp['description'][condition_key]}")

              if resp['success'] && resp['description'][condition_key] == condition_value
                 resp['description'].delete('success') if resp['description']['success']
                 ap_succ_resp(resp)
                 EM.stop
              else
                 if retries < MAX_RETRIES
                   puts_with_color('green', "[#{Time.now}] Still working.")
                   EM.add_timer(REQUEST_INTERVAL) do
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
          puts_with_color('red', "Fanally failed without response.")
          ap resp, :index => false, :indent => 2
          EM.stop
        end
      }

      http.errback {
        puts_with_color('red', "Error occurred: #{http.error}")
        EM.stop
      } 
    end 
  end
end  
