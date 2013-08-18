require "coffee-script"
Fitbit = require "fitbit"
mongoose = require 'mongoose'
moment = require "moment-timezone"
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
	oauthSettings = {}

	storedOauth = OauthModel.findOne()
	storedOauth.select "accessToken accessTokenSecret"

	storedOauth.exec (err, oauthSettings) ->
		if err
			console.log err
			return

		if !oauthSettings
			console.log "Please validate using the oauth tool first"
			return

		client = new Fitbit(config.CONSUMER_KEY, config.CONSUMER_SECRET,
			accessToken: oauthSettings.accessToken
			accessTokenSecret: oauthSettings.accessTokenSecret
			unitMeasure: "en_GB"
		)

		sync client
		setInterval sync, 3600000, client

sync = (client) ->
	client.getDevices (err, devices) ->
		lastSyncTime = moment(devices.device(0).lastSyncTime).format("X")

		client.getActivities (err, activities) ->
			return if err

			steps = new StepsModel {
				steps: activities.steps()
				date: new Date()
			}

			StepsModel.findOne({}, {}, {sort: {'date': -1}}, (err, doc) =>
				lastDate = moment(doc.date).format("X")

				if lastSyncTime > lastDate
					###steps.save (err) ->
						return if err###

					now = moment(new Date()).format("X")
					timeDiffSec = Math.round (now - lastDate)
					timeDiffMin = Math.round timeDiffSec / 60
					stepsDiff = activities.steps() - doc.steps

					message = stepsDiff + " steps in the last " + timeDiffMin + " minutes"

					#push.send "Get Off Your Ass", message
					console.log message
				else
					push.send "Get Off Your Ass", "Sync your FitBit!"
					console.log "FitBit data not up to date"

			)

init()