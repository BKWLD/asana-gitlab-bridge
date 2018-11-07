# Deps
axios = require 'axios'
_ = require 'lodash'

# Define the service
module.exports = class Gitlab
	
	# Build Axios client
	constructor: -> @client = axios.create
		baseURL: 'https://gitlab.com/api/v4'
		headers: 'Private-Token': process.env.GITLAB_ACCESS_TOKEN
	
	# Fetch list of projects for access token
	getProjects: ->
		{ data } = await @client.get '/projects', params:
			membership: 1
			per_page: 100
		projects = data.map (project) ->
			id: project.id
			name: project.name_with_namespace 
		return _.sortBy projects, 'name'
	
	# Create a webhook for a given project id
	createWebhook: (projectId) ->

	# Delete a webhook for a given project id
	deleteWebhook: (projectId) ->
	