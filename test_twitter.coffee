twitter = require './twitter'
util = require 'util'

streamSeed = {
	track: ['ducks'],
	follow: [],
	locations: []
}

twitter.pullList (followList) ->
  streamSeed.follow = followList
  console.log 'followList is', streamSeed.follow
  twitter.buildStream streamSeed, (newTweet) ->
    console.log 'newTweet', newTweet

process.on 'uncaughtException', (err) ->
  util.inspect err
