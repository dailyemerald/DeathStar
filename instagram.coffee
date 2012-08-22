request = require 'request'
credentials = require('./credentials').instagram
redisClient = require('redis').createClient()

exports.getAuthURL = ->
    "https://api.instagram.com/oauth/authorize/?client_id="     + credentials.client_id + "&redirect_uri=" + credentials.callback_uri + "&response_type=code"

exports.getDeleteURL = (subscriptionID) ->
    return "https://api.instagram.com/v1/subscriptions?client_secret=" + credentials.client_secret + "&id=" + subscriptionID + "&client_id=" + credentials.client_id

exports.getSubscriptionListURL = ->
    "https://api.instagram.com/v1/subscriptions?client_secret=" + credentials.client_secret + "&client_id=" + credentials.client_id

exports.getGeographyMediaRequest = (geographyID) ->
    "https://api.instagram.com/v1/geographies/" + geographyID + "/media/recent?client_id=" + credentials.client_id

exports.getTagMediaRequest = (tagName) ->
    "https://api.instagram.com/v1/tags/" + tagName + "/media/recent?client_id=" + credentials.client_id
  
exports.listSubscriptions = (callback) ->
  requestObj = {
    url: "https://api.instagram.com/v1/subscriptions?client_secret=" + credentials.client_secret + "&client_id=" + credentials.client_id
  }
  request requestObj, (error, response, body) ->
    callback JSON.parse body

exports.buildGeographySubscription = (builder, subscriptionCallback) ->
  #builder = {
  #    lat: 10,
  #    lng: 10,
  #    radius: 1000,
  #    streamID: 'a stream id'
  #}
  requestObj = {
    method: 'POST',
    url: 'https://api.instagram.com/v1/subscriptions/',
    form: {
      'client_id': credentials.client_id, 
      'client_secret': credentials.client_secret,
      'object': 'geography',
      'aspect': 'media', 
      'lat': builder.lat,
      'lng': builder.lng,
      'radius': builder.radius,
      'callback_url': credentials.callback_url + '/notify/' + builder.streamID #todo: get this out of hardcoding
    }
  }
  #console.log requestObj
  request requestObj, (error, response, body) ->
    if error is null
      subscriptionCallback null, '+ buildGeographySubscription'
    else
      subscriptionCallback '- error with buildSubscription!', null

exports.buildTagSubscription = (builder, subscriptionCallback) ->
    #builder = {
    #    tag: 'a tag',
    #    streamID: 'a stream id'
    #}
    requestObj = {
      method: 'POST',
      url: 'https://api.instagram.com/v1/subscriptions/',
      form: {
        'client_id': credentials.client_id, 
        'client_secret': credentials.client_secret,
        'object': 'tag',
        'aspect': 'media', 
        'object_id': builder.tag
        'callback_url': credentials.callback_url + "/notify/" + builder.streamID, #todo: get this out of hardcoding
      }
    }
    request requestObj, (error, response, body) ->
      if error is null
        subscriptionCallback null, '+ buildTagSubscription'
      else
        subscriptionCallback '- error with buildTagSubscription', null


# the guts are below #

#body is the raw, json encoded pack from the lookup... after the POST. 
#use a redis hash to keep track of what we've already seen
#could also do a sort based on created time... or a timediff threshold (server time sync issues with that?)

exports.checkAndProcessPhoto = (photo, callback) -> #callback is actually the function passed from who called getTagMedia. yikes.
  hash_key = "known_instagram_photos"
  redisClient.hexists hash_key, photo.id, (err, reply) ->
    #console.log 'hexists returned: err:', err, "reply:", reply, reply+1
    
    if reply is 0 # this means the key was NOT in the hash, so it's a new photo
      redisClient.hset hash_key, photo.id, JSON.stringify(photo), (err, reply) -> # mark this photo id as seen
        photo.iso_time = exports.makeISOtime photo.created_time
        #console.log 'firing callback in tag media for new picture!', photo.id
        callback null, photo #err, data
    else
      #console.log 'Dupe photo:', photo.id
      callback err, null

exports.processResultSet = (body, callback) ->
  hash_key = "previous_instagram"
  try 
    body = JSON.parse body
    objects = body.data
    for photo in objects
      exports.checkAndProcessPhoto photo, callback #look up one funciton for the implementation
  catch error
    callback error, null

exports.getTagMedia = (tagName, callback) ->
  #console.log 'getTagMedia lookup up', tagName
  requestObj = {
    url: exports.getTagMediaRequest tagName
  }
  request requestObj, (error, response, body) ->
    if response.statusCode is 200 #todo: does this need to be more robust?
      exports.processResultSet body, callback
    else 
      callback error, null # callback expects (err, data)

exports.getGeoMedia = (geographyID, callback) ->
  #console.log 'getGeoMedia lookup up', geographyID
  requestObj = {
    url: exports.getGeographyMediaRequest geographyID
  }
  request requestObj, (error, response, body) -> 
    if response.statusCode is 200 # todo: does this need to be more robust?
      exports.processResultSet body, callback
    else 
      callback error, null # callback expects (err, data)
  
# seems to work! unix time (seconds, not milliseconds) passed in as STRING
# returns STRING that is ISO8601
exports.makeISOtime = (secs) ->
  isoDate = new Date(1000*parseFloat(secs))
  isoDate = isoDate.toISOString()
  #console.log 'makeISOtime got', secs, 'and made', isoDate 
  return isoDate





# ### NOT USED, but here because it could be useful? ### #

# get the current object set for each subscription 
# returns an *unsorted* array of photos     
exports.buildInitalSet = (callback) ->    

  timeoutTime = ->
    callback 'buildInitalSet did not complete within 5 seconds -- timeout caught and returned early. this is bad.'
  timeoutHandle = setTimeout timeoutTime, 5000

  unsortedSeed = []; # baby DB!

  geoDone = false
  tagDone = false

  exports.listSubscriptions (subscriptions) ->

    areWeDoneYet = -> # oh the joys of async
      if tagDone and geoDone
        clearTimeout timeoutHandle # is it necessary to do this? will the timeout fire after the callback is called?
        callback unsortedSeed

    for subscription in subscriptions.data

      if subscription.object is 'geography'  
        exports.getGeoMedia subscription.object_id, (err, photos) ->
          if err
            throw err
          for photo in photos
            photo.created_time_int = parseFloat photo.created_time
            photo.created_time_iso = exports.makeISOtime photo.created_time
            unsortedSeed.push photo
          geoDone = true
          areWeDoneYet()

      else if subscription.object is 'tag'
        exports.getTagMedia subscription.object_id, (err, photos) ->
          if err
            throw err  
          for photo in photos
            photo.created_time_int = parseFloat photo.created_time
            photo.created_time_iso = exports.makeISOtime photo.created_time
            unsortedSeed.push photo
          tagDone = true
          areWeDoneYet()

      else
        throw 'unknown subscription type'
