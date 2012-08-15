express = require 'express'
http = require 'http'
fs = require 'fs'
request = require 'request'
_ = require 'underscore'
repl = require 'repl'
net = require 'net'
fs = require 'fs'

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

fakedb = []
db_name = 'db.json'

restoredb = ->
  fakedb = JSON.parse fs.readFileSync db_name
  console.log '+ Restored', fakedb.length, 'entries from file.'

dbsortfunc = (item) ->
     return 1 * item.time

syncdb = ->
  starttime = new Date()
  while fakedb.length > 50
    discardeditem = fakedb.shift()
    console.log 'discarded item'
  try  
    sorteddb = _.sortBy fakedb, dbsortfunc
    stringdb = JSON.stringify sorteddb
    fs.writeFileSync db_name, stringdb
    console.log '+ Synced to disk in', new Date() - starttime, 'milliseconds for', stringdb.length, 'characters.'
  catch error
    console.log 'Error while syncing to disk!', error
setInterval syncdb, 10*1000 #sync to disk every XX seconds

# this runs only on startup to restore state.
if fakedb.length is 0
  console.log '! Restoring db...'
  restoredb()



###################

sentIDs = []
instagramCounter = 0
twitterCounter = 0

###################

strencode = (data) ->
    unescape( encodeURIComponent( JSON.stringify( data ) ) )

reportCounters = ->
  console.log 'instagram:', instagramCounter, "\ttwitter:", twitterCounter, '\tcurrentClients', Object.keys(io.connected).length # TODO: push this data to graphite/statsd here?
  instagramCounter = 0
  twitterCounter = 0
  
setInterval reportCounters, 10000

app.get '/connected_clients', (req, res) ->
  res.send Object.keys(io.connected).length

#THE NOZZLE OF THE FUNNEL
pushNewItem = (item) ->
  
  fakedb.push item # add to in-mem database that is synced to disk sometimes for a restore
  io.sockets.emit 'newItem', strencode item 

  if item.type is 'instagram'
      instagramCounter++
      
  if item.type is 'twitter'
    twitterCounter++
    
###
  ROUTES
###

# this pulls the twitter list, then builds the Streaming API connection
twitter.pullList (listIDs) ->
  console.log '+ Twitter is rolling. List IDs:', listIDs
  setupData = {
    track: ['goducks', 'ducksgameday', 'odesports'],
    follow: listIDs#,
    #location: [44.053591,-123.077431,44.061663,-123.059353]
  }
  twitter.buildStream setupData, (newTweet) ->
    console.log 'buildStream in deathstar.coffee got a tweet', newTweet
    cleanTweet = {
      thumbnail: newTweet.user.profile_image_url,
      title: newTweet.user.name,
      content: newTweet.text,
      time: newTweet.created_at_iso
    }
    pushNewItem {'type': 'twitter', 'object': null, 'data': cleanTweet}
  


#socket io stuff
io.sockets.on 'connection', (socket) ->
  
  socket.on 'hello', (clientdata) ->
    
    socket.emit 'rebuild', fakedb    
  
  
      
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
            pushNewItem {'type': 'instagram', 'object': 'geo', 'data': data, 'time': data.iso_item} # MOVE THE ITEM INTO THE FUNNEL
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
      