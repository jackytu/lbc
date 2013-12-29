# coding: UTF-8

module LightBoxClient
  #default bridge address
  DEFAULT_LIGHTBOX_SERVER = "http://10.36.166.47:8080"
  #supported commands, just for help
  SUPPORTED_CMDS = ['boxes', 'create-user', 'password', 'delete-user', 'create', 'delete','delete-boxes', 'info', 'agents']
  #lbc will create cache file in its workspace
  WORKSPACE = ENV['HOME'] + '/.lbc'

  #command usages
  CMDS_USAGE = { 'Examples:' => {
    'Create new user' => './lbc create-user --email 5k@baidu.com --password changeme',
    'Change password' => './lbc password --password changeme2',
    'Create 1 redhat box' => './lbc create --name myboxes --memory 50 --image redhat --location 127.0.0.1',
    'Query a box with id 1' => './lbc info --boxid 1',
    'Create 3 boxes one time' => './lbc create --name myboxes --memory 50 --image centos --port 8082,8083 --batch 3 --local 127.0.0.1',
    'Query all my boxes' => './lbc boxes',
    'Delete a box with id 1' =>  './lbc delete --boxid 1',
    'Delete all my boxes' => './lbc delete-boxes',
    'Query all agents' => './lbc agents ',
    'Delete user' => './lbc delete-user',
    }
   }

  #command alias just to let operation easier
  CMDS_ALIAS = {
    'token' => 'get_token',
    'agents' => 'get_agents',
    'boxes' => 'get_boxes',
    'batch' => 'get_batch_stat',
    'delete-boxes' => 'delete_boxes',
    'create' => 'create_box',
    'create-user' => 'create_user',
    'delete' => 'delete_box',
    'delete-user' => 'delete_user',
    'info' => 'info_box',
    'password' => 'update_user',
    'register' => 'register_user'
  } 

  #supported bridge apis;
  #@api: the request uri
  #@method: http method
  #@need_token: if true, lbc will add token in the http head.
  LIGHTBOX_APIS = {
    :create_box => { 
        :api => "/container",
        :method => "post",
        :need_token => true
    },
    :delete_box => {
        :api => "/container/<boxid>",
        :method => "delete",
        :need_token => true
    },
    :delete_boxes => {
        :api => "/containers",
        :method => "delete",
        :need_token => true
    },
    :info_box => {
        :api => "container/<boxid>",
        :method => "get",
        :need_token => true
    },
    :create_user => {
        :api => "user",
        :method => "post",
        :need_token => true
    },
    :delete_user => {
        :api => "/user",
        :method => "delete",
        :need_token => true
    },
    :update_user => {
        :api => "user",
        :method => "put",
        :need_token => true
    },
    :register_user => {
        :api => "user",
        :method => "put",
        :need_token => false
    },
    :get_token => {
        :api => "token",
        :method => "get",
        :need_token => false
    },
    :get_boxes => {
        :api => "containers",
        :method => "get",
        :need_token => true
    },
    :get_agents => {
        :api => "agents",
        :method => "get",
        :need_token => true
    },
    :get_batch_stat => {
        :api => "batch/<batchid>",
        :method => "get",
        :need_token => true
    }
  }
end
