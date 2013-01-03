express = require 'express'
http = require 'http'
fs = require 'fs'
request = require 'request'
_ = require 'underscore'
repl = require 'repl'
net = require 'net'
fs = require 'fs'

#easymongo = require 'easymongo'
#mongo = new easymongo {db: 'deathstar_cw'}

redis = require 'redis'
redisClient = redis.createClient()
redisClient.on "error", (err) ->
  console.log "Redis Error", err

instagram = require './instagram'
twitter = require './twitter'

app = express.createServer()
server = app.listen 6767 #todo: move to env
io = require('socket.io').listen server
io.set 'log level', 2

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.logger("dev")
  app.use express.static(__dirname + "/public")
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.methodOverride()
  app.use express.errorHandler({showStack: true, dumpExceptions: true})

root = this
replPath = "/tmp/repl-app-deathstar"
fs.unlinkSync replPath #otherwise it's... in use? won't reconnect?
replNet = net.createServer (socket) ->
  r = repl.start({prompt: "deathstar> ", input: socket, output: socket, terminal: true, useGlobal: true})
          .on 'exit', ->
            socket.end()
  #r.context.io = io
  r.context = root
replNet.listen replPath

###################

dgram = require 'dgram'
statsClient = dgram.createSocket("udp4");

pushStat = (rawmessage) ->
  #console.log 'pushStat got:', rawmessage
  message = new Buffer rawmessage
  statsClient.send message, 0, message.length, 8125, "localhost", (err, bytes) ->
    if err
      console.log "Error in pushStat:", err

pushTimingStat = (start, end, name) ->
  diff = end - start 
  pushStat name+":"+diff+"|ms"

gettime = ->
  return new Date().getTime()

getRecentItems = (num, callback) ->
  start = gettime()
  redisClient.lrange 'feedl', 0, num, (err, dirtydata) ->
    cleandata = []
    for item in dirtydata
      cleandata.push JSON.parse item
    #pushTimingStat start, gettime(), 'feedl_'+num
    callback cleandata

###################

sentIDs = []
instagramCounter = 0
twitterCounter = 0

###################

strencode = (data) ->
    unescape( encodeURIComponent( JSON.stringify( data ) ) )

reportCounters = ->
  activeClients = Object.keys(io.connected).length
  pushStat 'active_clients:'+activeClients+'|g'
    
  memusage = process.memoryUsage()
  pushStat 'rss:'+parseInt(memusage.rss/(1024*1024))+"|g"
  pushStat 'heapTotal:'+parseInt(memusage.heapTotal/(1024*1024))+"|g"
  pushStat 'heapUsed:'+parseInt(memusage.heapUsed/(1024*1024))+"|g"
  pushStat 'uptime:'+parseInt(process.uptime())+"|g"
  
setInterval reportCounters, 10000

app.get '/connected_clients', (req, res) ->
  res.send Object.keys(io.connected).length

#THE NOZZLE OF THE FUNNEL
pushNewItem = (item) ->
  prepush = gettime()
  redisClient.incr 'feedl_id', (err, incr_id) ->
    item.d_id = incr_id
    redisClient.lpush 'feedl', JSON.stringify(item), (err, reply) ->
      pushTimingStat prepush, gettime(), 'lpush_feedl'
      console.log 'pushNewItem', item.type, item.time
      if err
        console.log "Redis lpush error:", err
        pushStat 'redis_lpush_error:100|c'

  #mongo.save 'items', item, (results) ->
  #  console.log 'mongosave:', results  
    
  io.sockets.emit 'newItem', strencode item # move this to redis pub/sub on another node instance?

  if item.type is 'instagram'
    pushStat 'incoming_instagram:1|c'
      
  if item.type is 'twitter'
    pushStat 'incoming_tweet:1|c'
    
###
  ROUTES
###

# this pulls the twitter list, then builds the Streaming API connection
twitter.pullList (listIDs) ->
  console.log '+ Twitter Streaming API is rolling. List IDs:', listIDs
  setupData = {
    track: ['goducks', 'uoasu', 'uoautzen', 'fiestabowl'],
    follow: listIDs#,
    #location: [44.053591,-123.077431,44.061663,-123.059353]
  }
  twitter.buildStream setupData, (newTweet) ->
    #console.log 'buildStream in deathstar.coffee got a tweet', newTweet
    cleanTweet = {
      thumbnail: newTweet.user.profile_image_url,
      title: newTweet.user.name,
      content: newTweet.text,
      #id_str: newTweet.id_str,
      iso_time: newTweet.iso_time
    }
    #console.log cleanTweet
    pushNewItem {'type': 'twitter', 'data': cleanTweet, 'time': cleanTweet.iso_time}
  


#socket io stuff
io.sockets.on 'connection', (socket) ->
  
  socket.on 'hello', (clientdata) ->
    pushStat 'socket_hello:1|c'
    #socket.emit 'rebuild', fakedb    
    getRecentItems 50, (items) ->
      socket.emit 'rebuild', items
      
  socket.on 'receivedNewItem', (clientdata) ->
    pushStat 'receivedNewItem:1|c'
   
  socket.on 'ping', (clientdata) ->
    socket.emit 'pong', {'time': new Date()}
    console.log 'ping', clientdata

  socket.on 'pull', (clientdata) ->
    console.log "socket: got pull."
    getRecentItems 50, (items) ->
      socket.emit 'incremental_rebuild', items
      
  socket.on 'resume', (clientdata) ->
    console.log "socket: resume:", clientdata    
  ###
  socket.emit 'ping'
  socket.pingstart = new Date();
  
  socket.on 'pong', (reply) ->
    socketdelay = parseInt( socket.pingstart - new Date() )
    console.log('socketdelay is', socketdelay)
    pushStat 'socket_delay:'+socketdelay+'|ms'
    socket.pingstart = null
    sockekdelay = null
  ###
      
################# ROUTES ##################

###
app.get '/rebuildInstagram', (req, res) ->
  instagram.buildInitalSet (unsortedPhotos) ->
    timeSort = (item) ->
       return -1 * item.created_time_int
    sortedPhotos = _.sortBy unsortedPhotos, timeSort
    res.json sortedPhotos
###

# Instagram POSTs here for new media.
app.all '/notify/:id', (req, res) -> # receives the real-time notification from IG
    if req.query and req.query['hub.mode'] is 'subscribe' #this only happens when the subscription is first built
      console.log '+ Confirming new Instagram real-time subscription...'
      res.send req.query['hub.challenge'] #should probably check this. then add it to the db lookup...?
      return
      
    # If we get here, we have a picture, not a confirmation for a new subscription    
    notifications = req.body
    #console.log '* Notification for', req.params.id, '. Had', notifications.length, 'item(s). Subscription ID:', req.body[0].subscription_id
    for notification in notifications

      if notification.object is "tag"
        instagram.getTagMedia notification.object_id, (err, data) ->
          #res.send data #todo: this will break if notifcations.length > 1. it rarely is. so it probably wont happen, but it should append and send once.
          # TODO: Do some cleanup here. Minimize data to send. Date formatter? 
          # TODO: Add to the database? 
          # Here we go:
          if data?
            pushNewItem {'type': 'instagram', 'object': 'tag', 'data': data, 'time': data.iso_time} # MOVE THE ITEM INTO THE FUNNEL
          else 
            console.log 'Instagram: in tag notification, no data!'
  
      else if notification.object is "geography"
        instagram.getGeoMedia notification.object_id, (err, data) ->
          #res.send data #todo: this will break if notifcations.length > 1. it rarely is. so it probably wont happen, but it should append and send once.
          # TODO: Do some cleanup here. Minimize data to send. Date formatter? 
          # TODO: Add to the database? 
          # Here we go:
          if data?
            pushNewItem {'type': 'instagram', 'object': 'geo', 'data': data, 'time': data.iso_time} # MOVE THE ITEM INTO THE FUNNEL
          else 
            console.log 'Instagram: in geo notification, no data!'
  
      else 
        console.log "Instagram notification object type is unknown:", notification.object
     
     res.send 200
      
app.get '/delete/:subscriptionID', (req, res) -> #todo: move this to the instagram module
  console.log '! Got delete request for', req.params.subscriptionID
  requestObj = {
    url: instagram.getDeleteURL(req.params.subscriptionID), #sanitize?
    method: 'DELETE'
  }
  request requestObj, (error, response, body) ->    
    res.send body

app.get '/listInstagram', (req, res) -> #list instagram subscriptions
  instagram.listSubscriptions (subscriptions) ->
    res.send subscriptions
      
app.get '/geo_goducks', (req, res) ->
  buildObj = {  
    lat: '44.058263', # this lat/lng is centered at Autzen (?)
    lng:'-123.068483', 
    radius: '4000', # in meters
    streamID: 'geo_goducks'
  }
  instagram.buildGeographySubscription buildObj, (err, data) -> 
    res.send err+'\n\n'+data

app.get '/tag_goducks', (req, res) ->
  buildObj = 
  instagram.buildTagSubscription {tag:'goducks', streamID:'tag_goducks'}, (err, data) ->
    if err?
      res.send err
    else
      res.send data      

app.get '/recent', (req, res) ->
  getRecentItems 20, (items) ->
    res.json items
      
process.on 'uncaughtException', (err) ->
  pushStat 'uncaughtException:1|c'
  console.error 'uncaughtException:', err.message
  console.error err.stack
