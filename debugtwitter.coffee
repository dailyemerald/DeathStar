TwitterLib = require 'tuiter'

credentials = require './credentials'

twitter = new TwitterLib({
  consumer_key: credentials.twitter.consumer_key,
  consumer_secret: credentials.twitter.consumer_secret,
  access_token_key: credentials.twitter.access_token_key,
  access_token_secret: credentials.twitter.access_token_secret
 });

repl = require("repl") 

r = repl.start({
  prompt: "> ",
  input: process.stdin,
  output: process.stdout,
})

r.context.twitter = twitter
