TwitterLib = require 'twit'
credentials = require './credentials'

exports.twitter = new TwitterLib({
  consumer_key: credentials.twitter.consumer_key,
  consumer_secret: credentials.twitter.consumer_secret,
  access_token: credentials.twitter.access_token_key,
  access_token_secret: credentials.twitter.access_token_secret
});

exports.pullList = (callback) ->
  exports.twitter.get 'lists/members', {'slug':'football-players', 'owner_screen_name':'dailyemerald', 'cursor':'-1'}, (err, reply) ->
    if err is null
      listIDs = []
      for user in reply.users
        listIDs.push user.id
      callback listIDs
    else
      callback []

exports.startStream = (followIDs, newTweetCallback)->
  #stream = exports.twitter.stream 'statuses/filter', { track:["USWNT", "goducks","love", "dailyemerald"], follow: followIDs, locations:[44.053591,-123.077431,44.061663,-123.059353] }
  stream = exports.twitter.stream 'statuses/filter', { track:["oregon"] }
  console.log 'startStream spinning up Twitter Streaming API...'
  stream.on 'tweet', (data) ->
    newTweetCallback data
  