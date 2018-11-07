# Deps
axios = require 'axios'
_ = require 'lodash'
db = new (require './db')

# Define the service
module.exports = class Asana
	
	# Build Axios client
	constructor: -> @client = axios.create
		baseURL: 'https://app.asana.com/api/1.0'
		headers: Authorization: "Bearer #{process.env.ASANA_ACCESS_TOKEN}"
	
	# Fetch list of projects for access token
	getProjects: ->
		{ data } = await @client.get '/projects'
		projects = data.data.map (project) -> 
			id: project.id
			name: project.name 
		return _.sortBy projects, 'name'
	
	# Create a webhook for a given project id
	createWebhook: (projectId) ->
		{ data } = await @client.post '/webhooks', data:
			resource: projectId
			target: "#{process.env.GATEWAY_URL}/asana/webhook"
		await db.put @webhookKeyName(projectId), data.data.id
		
	# Delete a webhook for a given project id
	deleteWebhook: (projectId) -> 
		if webhookId = await db.get @webhookKeyName(projectId)
			@client.delete "/webhooks/#{webhookId}"
			await db.delete @webhookKeyName(projectId)
	
	# Make the key for storing webhooks
	webhookKeyName: (projectId) -> "asana-#{projectId}-webhook-id"
