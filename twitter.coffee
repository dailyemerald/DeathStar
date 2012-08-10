#TwitterLib = require 'twit'
TwitterLib = require 'tuiter'

credentials = require './credentials'

twitter = new TwitterLib({
  consumer_key: credentials.twitter.consumer_key,
  consumer_secret: credentials.twitter.consumer_secret,
  access_token_key: credentials.twitter.access_token_key,
  access_token_secret: credentials.twitter.access_token_secret
 });
 
 
exports.pullList = (callback) ->
  twitter.listMembers {'slug':'football-players', 'owner_screen_name':'dailyemerald', 'cursor':'-1'}, (err, reply) ->
    listIDs = []
    if err is null
      for user in reply.users
        listIDs.push user.id
    callback listIDs

exports.buildStream = (trackTheseThings, newTweetCallback) ->
  #stream = exports.twitter.stream 'statuses/filter', { track:["USWNT", "goducks","love", "dailyemerald"], follow: followIDs, locations:[44.053591,-123.077431,44.061663,-123.059353] }
  console.log 'startStream spinning up Twitter Streaming API...'
  
  twitter.filter trackTheseThings, (stream) ->
    
    stream.on 'tweet', (data) ->
      console.log 'new tweet', data
      newTweetCallback data
    
    stream.on 'delete', (data) ->
      console.log 'delete!', data
      
    stream.on 'error', (data) ->
      console.log 'error!', data

exports.doSearch = (trackTheseThings, callback) ->
  console.log 'doSearch not implemented'
  