require "coffee-script"
express = require "express"
Fitbit = require "fitbit"
mongoose = require 'mongoose'
config = require "./config/app"
pushover = require "node-pushover"

app = express()
app.use express.cookieParser()
app.use express.session(secret: "hekdhthigib")
app.listen 3000

mongoose.connect 'mongodb://localhost/goya'

push = new pushover {
  token: config.PUSHOVER_TOKEN
  user: config.PUSHOVER_USER
}

StepsModel = mongoose.model 'Steps', {
  steps: Number
  date: Date
}

OauthModel = mongoose.model 'oauth', {
  accessToken: String
  accessTokenSecret: String
}

# OAuth flow
app.get "/", (req, res) ->
  # Create an API client and start authentication via OAuth
  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET)
  client.getRequestToken (err, token, tokenSecret) ->
    # Take action
    return  if err

    req.session.oauth =
      requestToken: token
      requestTokenSecret: tokenSecret

    storedOauth = OauthModel.findOne()
    storedOauth.select "accessToken accessTokenSecret"

    storedOauth.exec (err, oauthResponse) ->
      if err
        res.send "error accessing database"
        console.log err
        return

      if !oauthResponse
        res.redirect client.authorizeUrl(token)
        return

      oauthSettings = req.session.oauth
      oauthSettings.accessToken = oauthResponse.accessToken
      oauthSettings.accessTokenSecret = oauthResponse.accessTokenSecret

      res.redirect "/stats"


# On return from the authorization
app.get "/oauth_callback", (req, res) ->
  verifier = req.query.oauth_verifier
  oauthSettings = req.session.oauth

  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET)
  # Request an access token
  client.getAccessToken oauthSettings.requestToken, oauthSettings.requestTokenSecret, verifier, (err, token, secret) ->
    # Take action
    return  if err

    oauthObject = new OauthModel {
      accessToken: token
      accessTokenSecret: secret
    }

    oauthObject.save (err) ->
      console.log err if err

    oauthSettings.accessToken = token
    oauthSettings.accessTokenSecret = secret

    res.redirect "/stats"


# Display some stats
app.get "/stats", (req, res) ->
  if !req.session.oauth
    res.redirect "/"
    return

  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET,
    # Now set with access tokens
    accessToken: req.session.oauth.accessToken
    accessTokenSecret: req.session.oauth.accessTokenSecret
    unitMeasure: "en_GB"
  )

  client.getDevices (err, devices) ->
    lastSyncTime = devices.device(0).lastSyncTime

    # Fetch todays activities
    client.getActivities (err, activities) ->

      # Take action
      return if err

      steps = new StepsModel {
        steps: activities.steps()
        date: new Date()
      }

      #console.log lastSyncTime.getTime

      ###steps.save (err) ->
        console.log err if err###

      StepsModel.findOne({}, {}, {sort: {'date': -1}}, (err, doc) =>
        lastDate = doc.date
        now = new Date()
        timeDiffSec = Math.round (now.getTime() - lastDate.getTime()) / 1000
        timeDiffMin = Math.round timeDiffSec / 60
        stepsDiff = activities.steps() - doc.steps
        #push.send "Get Off Your Ass", stepsDiff + " steps in the last " + timeDiffMin + " minutes"
        res.send stepsDiff + " steps in the last " + timeDiffMin + " minutes"
      )