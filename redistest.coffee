client = require('redis').createClient()

dgram = require 'dgram'
statsClient = dgram.createSocket("udp4");

pushStat = (rawmessage) ->
  #console.log 'pushStat got:', rawmessage
  message = new Buffer rawmessage
  console.log 'message:', rawmessage
  statsClient.send message, 0, message.length, 8125, "localhost", (err, bytes) ->
    if err
      console.log "Error in pushStat:", err

pushTimingStat = (start, end, name) ->
  diff = end - start 
  pushStat name+":"+diff+"|ms"

gettime = ->
  return new Date().getTime()

getRecentTweets = (num, callback) ->
  start = gettime()
  client.lrange 'feedl', 0, num, (err, data) ->
    pushTimingStat start, gettime(), 'feedl_'+num
    callback data
