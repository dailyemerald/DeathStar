express = require 'express'
http = require 'http'
fs = require 'fs'
request = require 'request'
credentials = require './credentials'
instagram = require './instagram'
twitter = require './twitter'

instagram.setCredentials(credentials.instagram) #this could be done in instagram module...

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

strencode = (data) ->
    unescape( encodeURIComponent( JSON.stringify( data ) ) )

#THE NOZZLE OF THE FUNNEL
pushNewItem = (item) ->
  console.log '> Push', item.data.id, 'to', io.sockets.length, 'websocket clients.'
  io.sockets.emit 'newItem', strencode item 

###
  ROUTES
###

twitter.pullList (listIDs) ->
  console.log '+ Twitter is rolling. List IDs:', listIDs
  twitter.startStream listIDs, (newTweet) ->
    console.log newTweet
  

app.get '/', (req, res) -> # Not public facing. Just a funnel.
  res.send "This is not the webpage you are looking for."

# Instagram POSTs here for new media.
app.all '/notify/:id', (req, res) -> # receives the real-time notification from IG
    if req.query and req.query['hub.mode'] is 'subscribe' #this only happens when the subscription is first built
      console.log '+ Confirming new Instagram real-time subscription...'
      res.send req.query['hub.challenge'] #should probably check this. then add it to the db lookup...?
      return
      
    # If we get here, we have a picture, not a confirmation for a new subscription    
    notifications = req.body
    console.log '* Notification for', req.params.id, '. Had', notifications.length, 'item(s). Subscription ID:', req.body[0].subscription_id
    for notification in notifications
      #console.log notification
      
      if notification.object is "tag"
        instagram.getTagMedia notification.object_id, (err, data) ->
          #res.send data #todo: this will break if notifcations.length > 1. it rarely is. so it probably wont happen, but it should append and send once.
          # TODO: Do some cleanup here. Minimize data to send. Date formatter? 
          # TODO: Add to the database? 
          # Here we go:
          pushNewItem {'type': 'instagram', 'object': 'tag', 'data': data} # MOVE THE ITEM INTO THE FUNNEL
  
      else if notification.object is "geography"
        instagram.getGeoMedia notification.object_id, (err, data) ->
          #res.send data #todo: this will break if notifcations.length > 1. it rarely is. so it probably wont happen, but it should append and send once.
          # TODO: Do some cleanup here. Minimize data to send. Date formatter? 
          # TODO: Add to the database? 
          # Here we go:
          pushNewItem {'type': 'instagram', 'object': 'geo', 'data': data} # MOVE THE ITEM INTO THE FUNNEL
  
      else 
        console.log "notification object type is unknown:", notification.object

###  
app.get '/delete/:subscriptionID', (req, res) -> #todo: move this to the instagram module
  console.log '! Got delete request for', req.params.subscriptionID
  requestObj = {
    url: instagram.getDeleteURL(req.params.subscriptionID),
    method: 'DELETE'
  }
  request requestObj, (error, response, body) ->    
    body = JSON.parse body
    if body.meta.code is 200
      res.send body
    else 
      res.send body
###

app.get '/listInstagram', (req, res) -> #list instagram subscriptions
  console.log 'get listInstagram'
  instagram.listSubscriptions (subscriptions) ->
    console.log 'listSubscriptions callback'
    res.send subscriptions
      
app.get '/build_instagram_geo', (req, res) ->
  buildObj = {  
    lat: '44.058263', # this lat/lng is centered at Autzen
    lng:'-123.068483', 
    radius: '4000', # in meters
    streamID: 'uo_geo'
  }
  instagram.buildGeographySubscription buildObj, (err, data) -> 
    if err?
      res.send 'err', err
    else
      res.send 'yay', data

app.get '/build_instagram_tag', (req, res) ->
  buildObj = {  
    tag: 'oregonfootball', 
    streamID: 'love_tag'
  }
  instagram.buildTagSubscription buildObj, (err, data) -> #4km around UO campus
    if err?
      res.send 'err<br><br>'+err
    else
      res.send 'yay<br><br>'+data

#socket io stuff
io.sockets.on 'connection', (socket) ->
  console.log 'Socket connection!'