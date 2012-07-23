request = require 'request'

exports.setCredentials = (credentials) ->
    exports.credentials = credentials
    #console.log '* Instagram credentials set as', credentials

exports.getAuthURL = ->
    "https://api.instagram.com/oauth/authorize/?client_id="     + exports.credentials.client_id + "&redirect_uri=" + exports.credentials.callback_uri + "&response_type=code"

exports.getDeleteURL = (subscriptionID) ->
    "https://api.instagram.com/v1/subscriptions?client_secret=" + exports.credentials.client_secret + "&id=" + subscriptionID + "&client_id=" + exports.credentials.client_id

exports.getSubscriptionListURL = ->
    "https://api.instagram.com/v1/subscriptions?client_secret=" + exports.credentials.client_secret + "&client_id=" + exports.credentials.client_id

exports.getGeographyMediaRequest = (geographyID) ->
    "https://api.instagram.com/v1/geographies/" + geographyID + "/media/recent?client_id=" + exports.credentials.client_id

exports.getTagMediaRequest = (tagName) ->
    "https://api.instagram.com/v1/tags/" + tagName + "/media/recent?client_id=" + exports.credentials.client_id
  
exports.listSubscriptions = (callback) ->
  requestObj = {
    method: 'GET',
    url: exports.getSubscriptionListURL
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
      'client_id': exports.credentials.client_id, 
      'client_secret': exports.credentials.client_secret,
      'object': 'geography',
      'aspect': 'media', 
      'lat': builder.lat,
      'lng': builder.lng,
      'radius': builder.radius,
      'callback_url': exports.credentials.callback_url + '/notify/' + builder.streamID #todo: get this out of hardcoding
    }
  }
  console.log requestObj
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
        'client_id': exports.credentials.client_id, 
        'client_secret': exports.credentials.client_secret,
        'object': 'tag',
        'aspect': 'media', 
        'object_id': builder.tag
        'callback_url': exports.credentials.callback_url + "/notify/" + builder.streamID, #todo: get this out of hardcoding
      }
    }
    request requestObj, (error, response, body) ->
      if error is null
        subscriptionCallback null, '+ buildTagSubscription'
      else
        subscriptionCallback '- error with buildTagSubscription', null

exports.getTagMedia = (tagName, callback) ->
  #console.log 'getTagMedia lookup up', tagName
  requestObj = {
    url: exports.getTagMediaRequest tagName
  }
  request requestObj, (error, response, body) ->
    if not error and response.statusCode is 200 #todo: does this need to be more robust?
      try 
        body = JSON.parse body
        objects = body.data
        lastObject = objects.pop() #TODO! check if there's more than one new thing. 
        callback null, lastObject #err, data
      catch error
        callback error, null
        
    else 
      body = JSON.parse body
      callback body, null #err, data


exports.getGeoMedia = (geographyID, callback) ->
  #console.log 'getGeoMedia lookup up', geographyID
  requestObj = {
    url: exports.getGeographyMediaRequest geographyID
  }
  request requestObj, (error, response, body) ->
    if not error and response.statusCode is 200 #todo: does this need to be more robust?
      body = JSON.parse body
      objects = body.data
      lastObject = objects.pop #TODO! check if there's more than one new thing. 
      callback null, lastObject #err, data 
    else 
      callback body, null #err, data
