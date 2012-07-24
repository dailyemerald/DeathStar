TwitterLib = require 'twit'
credentials = require './credentials'

console.log credentials.twitter

twitter = new TwitterLib({
  consumer_key: credentials.twitter.consumer_key,
  consumer_secret: credentials.twitter.consumer_secret,
  access_token: credentials.twitter.access_token_key,
  access_token_secret: credentials.twitter.access_token_secret
});

exports.pullList = ->
  twitter.get 'lists/members', {'slug':'football-players', 'owner_screen_name':'dailyemerald', 'cursor':'-1'}, (err, reply) ->
    if err is null
      listIDs = []
      for user in reply.users
        listIDs.push user.id
      listIDs
    else
      []

exports.startStream = (followIDs, newTweetCallback)->
  stream = twitter.stream 'statuses/filter', { track:["goducks","dailyemerald"], follow: followIDs, locations:[44.053591,-123.077431,44.061663,-123.059353] }
  stream.on 'tweet', (data) ->
    newTweetCallback data
  