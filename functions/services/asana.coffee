# Deps
axios = require 'axios'
_ = require 'lodash'

# Define the service
module.exports = class Asana
	
	# Build Axios client
	constructor: -> @axios.create
		baseURL: 'https://app.asana.com/api/1.0'
		headers: Authorization: "Bearer #{process.env.ASANA_ACCESS_TOKEN}"
	
	# Fetch list of projects for access token
	getProjects: ->
		response = await @client.get '/projects'
		projects = response.data.data.map (project) -> 
			id: project.id
			name: project.name 
		return _.sortBy projects, 'name'
	
	# Delete a webhook for a given project id
	deleteWebhook: (projectId) ->
	
	# Create a webhook for a given project id
	createWebhook: (projectId) ->