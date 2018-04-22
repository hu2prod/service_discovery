# service_discovery
Usage
  * Create `service_discovery.json` for server
    * set `port`
    * set `ws_port`
  * Create separate `service_discovery.json` or add to existing one for client
    * set `main_ip` to fixed IP or 'ip_to_1'
    * set `service_name`
  * Add to your service `require('service_discovery').client()`
  * create new `service_discovery.coffee` server with contents
```
#!/usr/bin/env iced
require('service_discovery').server()
```
  * Start `service_discovery.coffee` server and start some clients
  * Connect to your service_discovery server with `ws_wrap` module on ws_port
  * See JSON messages with service2ip and ip2service hashes
    * service_name > ip > last_ts
    * ip > service_name > last_ts
# How it works

Client is sending heartbeat get request to service_discovery server every `poll_interval` from config or every 1 sec.
Service discovery server keeps last timestamp for each service and each ip.
Subscriber must filter services by 2 or 3 times `poll_interval` filter for detecting alive services.

# Future changes

 * service uptime info
 * optinal service telemetry
   * cpu load
 * http -> ws heartbeat
   * 2 separate websocket servers. Do not send any subscribe message for stream start.
 * BREAKING CHANGES. Is connection alive info in subscribe data
 * Proper throttle.
   * Send immidiately if connect/disconnect
   * Send 1 sec after last message on this socket
 * ws_boost usage when ready.
