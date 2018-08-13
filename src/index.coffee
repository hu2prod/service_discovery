module = @
require 'fy'
require 'fy/experimental'
fs  = require 'fs'
os  = require 'os'
ws  = require 'ws'
http= require 'http'
url = require 'url'
@config = "./service_discovery.json"

@_read_config = (opt={})->
  manual_config = opt.config
  loop
    if !fs.existsSync module.config
      break if manual_config
      throw new Error "Can't find config #{module.config}"
    
    config_str = fs.readFileSync module.config
    try
      config = JSON.parse config_str
    catch e
      throw new Error "Can't parse config. #{e.message}"
    obj_set config, manual_config
    break
  
  if !config.port?
    throw new Error "Can't find port for discovery service"
  
  if opt.server
    if !config.ws_port?
      throw new Error "Can't find ws_port in config"
  
  if opt.client
    if !config.main_ip?
      throw new Error "Can't find main_ip in config"
    
    if !config.service_name?
      throw new Error "Can't find service_name in config"
  
  config

class Service_discovery_service
  service2ip_hash_hash : {}
  ip2service_hash_hash : {}
  _service_table_version_id : 0
  port    : 0
  ws_port : 0
  _ws_server : null
  _http_server : null
  
  constructor:({@port, @ws_port})->
    @service2ip_hash_hash = {}
    @ip2service_hash_hash = {}
    @start()
  
  start : ()->
    # ###################################################################################################
    #    http
    # ###################################################################################################
    @_http_server = http.createServer (req, res)=>
      req_url = url.parse "http://#{req.url}", true
      if req_url.pathname == '/heartbeat'
        ip = req.socket.remoteAddress
        if /^::ffff:/.test ip
          ip = ip.replace /^::ffff:/, ''
        {service_name} = req_url.query
        @service_heartbeat ip, service_name
      
      res.writeHead 200, {}
      res.end ''
    @_http_server.on 'clientError', (err, socket) =>
      socket.end('HTTP/1.1 400 Bad Request\r\n\r\n')
    
    @_http_server.listen @port
    # ###################################################################################################
    #    ws
    # ###################################################################################################
    ws_server = new ws.Server port : @ws_port
    # TODO ws_boost
    ws_server.on 'connection', (socket)=>
      now = Date.now()
      loc_v_id = -1
      update = ()=>
        return if loc_v_id == @_service_table_version_id
        loc_v_id = @_service_table_version_id
        msg = {
          service2ip : @service2ip_hash_hash
          ip2service : @ip2service_hash_hash
        }
        socket.send JSON.stringify msg, null, 2
      update()
      # TODO proper throttle
      
      interval = setInterval update, 1000
      socket.on 'close', ()->
        clearTimeout interval
    
    return
  
  close : ()->
    @_http_server.close()
    @_ws_server.close()
    return
  
  service_heartbeat : (ip, service_name)->
    @service2ip_hash_hash[service_name] ?= {}
    @ip2service_hash_hash[ip] ?= {}
    
    now = Date.now()
    @service2ip_hash_hash[service_name][ip] = now
    @ip2service_hash_hash[ip][service_name] = now
    
    @_service_table_version_id = (@_service_table_version_id+1) % 4096
    return

@server = (config)->
  config = module._read_config {config, server:true}
  new Service_discovery_service config

@client = (config)->
  config = module._read_config {config, client:true}
  # ###################################################################################################
  #    main_ip detect
  # ###################################################################################################
  {
    main_ip
    port
    service_name
  } = config
  poll_interval = config.poll_interval or 1000
  
  if main_ip == "ip_to_1"
    ip_list = []
    for k, ip_conf_list of os.networkInterfaces()
      for ip_conf in ip_conf_list
        continue if ip_conf.family != 'IPv4'
        continue if ip_conf.address == '127.0.0.1'
        ip_list.push ip_conf.address
    if ip_list.length == 0
      throw new Error "can't detect ip. No ipv4 found"
    
    if ip_list.length > 1
      loop
        if config.filter?
          regex = new RegExp config.filter
          ip_list = ip_list.filter (t)->regex.test t
          if ip_list.length == 0
            throw new Error "can't detect ip. All ip filtered out"
          if ip_list.length == 1
            break
        
        perr ip_list
        throw new Error "can't detect ip. Multiple ipv4 found"
        break
    
    [main_ip] = ip_list
    list = main_ip.split '.'
    list.pop()
    list.push '1'
    main_ip = list.join '.'
  # ###################################################################################################
  #    request loop
  # ###################################################################################################
  
  working = true
  do ()->
    while working
      req = http.get "http://#{main_ip}:#{port}/heartbeat?service_name=#{service_name}"
      req.setTimeout 2000
      req.end()
      await
        cb = (defer()).wrap_once()
        req.once 'response', cb
        req.on 'error', (e)->
          perr "sevrice discovery server error #{e.message}"
          cb()
      await setTimeout defer(), poll_interval
  {
    stop : ()->
      working = false
      return
  }