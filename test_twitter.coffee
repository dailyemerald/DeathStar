twitter = require './twitter'
util = require 'util'

streamSeed = {
	track: ['goducks', 'ducksgameday', 'dailyemerald', 'odesports'],
	follow: []#,
	#locations: []
}

# {lat: 44.044942, long: -123.088627}, {lat: 44.065221, long:-123.058881}

twitter.pullList (followList) ->
  streamSeed.follow = followList
  console.log 'followList is', streamSeed.follow.length, 'long'
  
  twitter.buildStream streamSeed, (data) ->
     
    if data.coordinates and data.coordinates.coordinates
          console.log "coord", data.coordinates.coordinates, data.user.screen_name, data.text
          
    if data.place
      place = data.place.bounding_box.coordinates[0][0]
      console.log "place", place, data.user.screen_name, data.text
    
    console.log "\t>>>\t", data.user.screen_name, "\t\t", data.text

process.on 'uncaughtException', (err) ->
  console.log err
  util.inspect err
