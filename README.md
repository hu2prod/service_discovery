# service_discovery
Usage
  * Create service_discovery.json for server
    * set port
    * set ws_port
  * Create separate service_discovery.json or add to existing one for client
    * set main_ip to fixed IP or 'ip_to_1'
    * set service_name
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
