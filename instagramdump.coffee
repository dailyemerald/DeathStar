redis = require('redis').createClient()
express = require('express')
winston = require('winston')

winston.add winston.transports.File, {filename: 'instagramdump.log'}

app = express()
app.listen 6768

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.logger("dev")
  app.use express.static(__dirname + "/public")
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.methodOverride()
  app.use express.errorHandler({showStack: true, dumpExceptions: true})

### helpers ###

now = ->
  new Date().getTime()

logTime = (name, start, end) ->
  diff = end - start
  winston.log 'info', name, {time: diff}



### main stuff ###

getPhotos = (callback) ->
  startTime = now()
  redis.hgetall 'known_instagram_photos', (err, data) ->
    logTime 'getPhotos lookup time', startTime, now()
    callback data

app.get '/photos', (req, res) ->
  reqStart = now()
  getPhotos (photos) ->
    clean = []
    for key in Object.keys(photos)
      try
        tojson = JSON.parse photos[key]
        clean.push tojson
      catch err
        console.log 'invalid json:', key
    res.json clean
    clean = null
    logTime 'GET /photos', reqStart, now()
    console.log process.memoryUsage()


