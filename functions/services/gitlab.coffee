# Deps
axios = require 'axios'
_ = require 'lodash'
db = new (require './db')
asana = new (require './asana')

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
	createWebhook: (entryId, projectId) ->
		{ data } = await @client.post "/projects/#{projectId}/hooks",
			url: "#{process.env.GATEWAY_URL}/gitlab/webhook?entry=#{entryId}"
			issues_events: true
			push_events: false
			enable_ssl_verification: true
		await db.put @webhookKey(entryId), 
			webhookId: data.id
			projectId: projectId
		
	# Delete a webhook for a given project id
	deleteWebhook: (entryId) -> 
		if payload = await db.get @webhookKey entryId
			{ webhookId, projectId } = payload
			await @client.delete "/projects/#{projectId}/hooks/#{webhookId}"
			await db.delete @webhookKey entryId
	
	# Make the key for storing webhooks
	webhookKey: (entryId) -> "gitlab-#{entryId}-webhook-id"
	
	# Create a issue from an Asana task
	createIssue: (projectId, task) ->
		{ data } = await @client.post "/projects/#{projectId}/issues",
			title: task.name
			description: task.notes
		await @addTimeEstimate projectId, data.iid, 
			asana.customFieldValue task, asana.ESTIMATE_FIELD
		return data
		
	# Add the time estimat to the issue automatically
	addTimeEstimate: (projectId, issueId, hours) ->
		@client.post "/projects/#{projectId}/issues/#{issueId}/time_estimate",
			duration: "#{hours}h"
	
	# Create a milestone (if necessary) to match the Asana task and then associate
	# the issue with it
	syncIssueToMilestone: (task) ->
