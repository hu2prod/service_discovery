#!/usr/bin/env iced
### !pragma coverage-skip-block ###
require 'fy'
srv = require('./src/index').server()
do ()->
  loop
    p srv.ip2service_hash_hash
    await setTimeout defer(), 1000
p "started"
