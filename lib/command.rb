# coding: UTF-8
require "membrane"
require "json"

module LightBoxClient
  class Command

    #translate the attributes of command
    #+ @params [Hash] attributes to translate
    #+ @return [Hash] attributes translated
    def self.translate_attributes(attributes)
      attributes = attributes.dup
      attributes[:lightbox]  ||= DEFAULT_LIGHTBOX_SERVER
      attributes[:command] = translate_command(attributes[:command])
      attributes
    end
    
    #format lightbox uri, make sure it a standard http uri;
    #+ @params [String] raw lightbox uri
    #+ @return [String] standard http uri
    def self.format_lightbox(lightbox)
      lightbox.insert(0,"http://") unless lightbox =~ /^http:\/\//
      lightbox
    end

    #translate command from user input to real protocol method.
    def self.translate_command(command)
      cmd_alias = LightBoxClient::CMDS_ALIAS.fetch(command, nil)
      cmd_alias ||= command
      cmd_alias
    end

    #format lightbox style uri, erease protocol item 'http/https'.
    #+ @params [String] raw uri;
    #+ @return [String] lightbox style uri.
    def self.format_uri(uri)
      return unless uri
      uri_no_http = uri.gsub(/https?:\/\//, "")
      uri_no_http.gsub(/\/$/, "")
    end

    def self.schema
      Membrane::SchemaParser.parse do
        {
          :command                  => enum('get_agents', 'get_token', 'register_user', 'create_user', 'update_user', 'delete_user', 'create_box', 'delete_box', 'delete_boxes', 'info_box', 'get_boxes', 'get_batch_stat'),
          :lightbox               => String,
          optional(:token)          => String,
          optional(:email)          => String,
          optional(:password)         => String,
          optional(:newpassword)      => String,
          optional(:boxid)         => String,
          optional(:batch)         => Integer,
          optional(:batchid)         => String,
          optional(:name)         => String,
          optional(:image)         => String,
          optional(:limits)         => Hash,
          optional(:ports)          => String
        }
      end
    end

    self.schema.schemas.each do |key, _|
      define_method(key) do
        attributes[key]
      end
    end
    
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes.dup
    end

    #validate the attributes of command
    def validate
      self.class.schema.validate(attributes)    
      rescue Membrane::SchemaValidationError => ve
        p "Validate command schema failed with #{ve}"
      end
    end

    #generate the payload of http request
    #payload should be standard brigec protocol
    def payload
      LightBoxClient::Protocol.new(self).send("#{command}_protocol")
    end

    [:api, :method, :need_token].each do |key|
       define_method(key.to_s) do
         cmd_alias = LightBoxClient::CMDS_ALIAS.fetch(command, nil)
         cmd_alias ||= command
         LIGHTBOX_APIS[cmd_alias.to_sym][key]
       end
    end

  end
end
