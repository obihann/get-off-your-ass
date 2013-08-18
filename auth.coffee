require "coffee-script"
Fitbit = require "fitbit"
express = require "express"
mongoose = require 'mongoose'
config = require "./config/app"

app = express()
app.use express.cookieParser()
app.use express.session(secret: "hekdhthigib")
app.listen 3000

mongoose.connect "mongodb://"+config.MONGO_USER+":"+config.MONGO_PASS+".mongolab.com:41238/goya"

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

      console.log oauthResponse

      if !oauthResponse
        res.redirect client.authorizeUrl(token)
        return

      oauthSettings = req.session.oauth
      oauthSettings.accessToken = oauthResponse.accessToken
      oauthSettings.accessTokenSecret = oauthResponse.accessTokenSecret

      res.redirect "/success"


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

    res.redirect "/success"


# Display some stats
app.get "/success", (req, res) ->
  if !req.session.oauth
    res.redirect "/"
    return

  res.send "success!"