require "coffee-script"
express = require "express"
Fitbit = require "fitbit"
mongoose = require 'mongoose'
config = require "./config/app"

app = express()
app.use express.cookieParser()
app.use express.session(secret: "hekdhthigib")
app.listen 3000

mongoose.connect 'mongodb://localhost/goya'

StepsModel = mongoose.model 'Steps', {
  steps: Number
  date: Date
}

OauthModel = mongoose.model 'oauth', {
  requestToken: String
  requestTokenSecret: String
  verifier: String
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
  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET,
    # Now set with access tokens
    accessToken: req.session.oauth.accessToken
    accessTokenSecret: req.session.oauth.accessTokenSecret
    unitMeasure: "en_GB"
  )

  # Fetch todays activities
  client.getActivities (err, activities) ->

    # Take action
    return if err

    # `activities` is a Resource model
    res.send "Total steps today: " + activities.steps()

    steps = new StepsModel {
      steps: activities.steps()
      date: new Date()
    }

    steps.save (err) ->
      console.log err if err