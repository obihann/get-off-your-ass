require "coffee-script"
Fitbit = require "fitbit"
mongoose = require 'mongoose'
config = require "./config/app"
pushover = require "node-pushover"

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

init = () ->
  # Create an API client and start authentication via OAuth
  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET)
  client.getRequestToken (err, token, tokenSecret) ->
    # Take action
    return  if err

    oauthSettings = {
      requestToken: token
      requestTokenSecret: tokenSecret
    }

    storedOauth = OauthModel.findOne()
    storedOauth.select "accessToken accessTokenSecret"

    storedOauth.exec (err, response) ->
      if err
        console.log err
        return

      if !response
        console.log "Please validate using the oauth tool first"
        return

      oauthSettings.accessToken = response.accessToken
      oauthSettings.accessTokenSecret = response.accessTokenSecret

      sync oauthSettings

sync = (oauth) ->
  client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET,
    # Now set with access tokens
    accessToken: oauth.accessToken
    accessTokenSecret: oauth.accessTokenSecret
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

      StepsModel.findOne({}, {}, {sort: {'date': -1}}, (err, doc) =>
        lastDate = doc.date
        now = new Date()
        timeDiffSec = Math.round (now.getTime() - lastDate.getTime()) / 1000
        timeDiffMin = Math.round timeDiffSec / 60
        stepsDiff = activities.steps() - doc.steps
        message = stepsDiff + " steps in the last " + timeDiffMin + " minutes"
        push.send "Get Off Your Ass", message
        console.log message
      )

init()