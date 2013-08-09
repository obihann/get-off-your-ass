express = require("express")
config = require('./config/app')
app = express()
Fitbit = require("fitbit")
app.use express.cookieParser()
app.use express.session(secret: "hekdhthigib")
app.listen 3000

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

    res.redirect client.authorizeUrl(token)



# On return from the authorization
app.get "/oauth_callback", (req, res) ->
  verifier = req.query.oauth_verifier
  oauthSettings = req.session.oauth
  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET)
  
  # Request an access token
  client.getAccessToken oauthSettings.requestToken, oauthSettings.requestTokenSecret, verifier, (err, token, secret) ->
    
    # Take action
    return  if err
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