request = require 'request'
credentials = require('./credentials').instagram

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

exports.getTagMedia = (tagName, callback) ->
  #console.log 'getTagMedia called'
  #console.log 'getTagMedia lookup up', tagName
  requestObj = {
    url: exports.getTagMediaRequest tagName
  }
  request requestObj, (error, response, body) ->
    #console.log error, response.statusCode, typeof response.statusCode is 200
    if response.statusCode is 200 #todo: does this need to be more robust?
      try 
        body = JSON.parse body
        objects = body.data
        #lastObject = objects.pop() #TODO! check if there's more than one new thing. 
        #console.log lastObject, 'lastObject'
        callback null, objects #err, data
      catch error
        callback error, null
        
    else 
      #console.log "ERRORZZZ", response.statusCode
      callback error, null #err, data


exports.getGeoMedia = (geographyID, callback) ->
  #console.log 'getGeoMedia lookup up', geographyID
  requestObj = {
    url: exports.getGeographyMediaRequest geographyID
  }
  request requestObj, (error, response, body) -> 
    #console.log error, response.statusCode, typeof response.statusCode is 200
    try
      if not error and response.statusCode is 200 #todo: does this need to be more robust? 
        body = JSON.parse body
        objects = body.data
        #lastObject = objects.pop() #TODO! check if there's more than one new thing. 
        #console.log 'lastObject', lastObject
        callback null, objects #err, data 
      else 
        callback body, null #err, data
        
    catch error
      callback error, null
  
  
      
# get the current object set for each subscription 
# returns an unsorted array of photos     
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
          for photo in photos
            photo.created_time_int = parseFloat photo.created_time
            unsortedSeed.push photo
          geoDone = true
          areWeDoneYet()

      else if subscription.object is 'tag'
        exports.getTagMedia subscription.object_id, (err, photos) ->
          for photo in photos
            photo.created_time_int = parseFloat photo.created_time
            unsortedSeed.push photo
          tagDone = true
          areWeDoneYet()

      else
        throw 'unknown subscription type'
