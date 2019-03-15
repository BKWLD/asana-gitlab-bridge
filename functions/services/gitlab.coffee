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
		
		# Get meta data
		await meta = await asana.getMeta task
		
		# Make the list of "tags", some of which may be optional
		tagsLine = [ meta.comments, meta.date ]
		.filter (tag) -> !!tag
		.map (tag) -> "`#{tag}`"
		.join ' '
		
		# Create the issue
		{ data } = await @client.post "/projects/#{projectId}/issues",
			title: task.name
			description: """
				💬 Created from **[this Asana Task](#{asana.taskUrl(task)})** 
				by [#{meta.author.name}](#{meta.author.url})
				#{tagsLine}
				
				---
				
				#{task.notes}
				"""
			labels: asana.getLabels(task).join ''
				
		# Add time estimate
		await @addTimeEstimate projectId, data.iid, 
			asana.customFieldValue task, asana.ESTIMATE_FIELD
		
		# Set the initial milestone
		await @setMilestone projectId, task, data
		
		# Return the issue data
		return data
		
	# Add the time estimat to the issue automatically
	addTimeEstimate: (projectId, issueId, hours) ->
		return unless hours
		@client.post "/projects/#{projectId}/issues/#{issueId}/time_estimate",
			duration: "#{hours}h"
	
	# Create a milestone (if necessary) to match the Asana task and then associate
	# the issue with it
	syncIssueToMilestone: (projectId, task) ->
		issue = await @getIssueFromUrl projectId,
			asana.customFieldValue task, asana.ISSUE_FIELD
		@setOrClearMilestone projectId, task, issue
	
	# Set or clear the milestone on an issue
	setOrClearMilestone: (projectId, task, issue) ->
		if asana.inMilestone task
		then @setMilestone projectId, task, issue
		else @clearMilestone projectId, task, issue
	
	# Set the milestone of an issue
	setMilestone: (projectId, task, issue) ->
		name = asana.milestoneName task
		milestone = await @findOrCreateMilestone projectId, name
		if issue.milestone?.id != milestone.id
			await @client.put "/projects/#{projectId}/issues/#{issue.iid}",
				milestone_id: milestone.id
			await asana.updateStatus task, asana.PENDING_STATUS
	
	# Clear the milestone of a task and issue
	clearMilestone: (projectId, task, issue) ->
		await @client.put "/projects/#{projectId}/issues/#{issue.iid}",
			milestone_id: null
		await asana.updateStatus task, asana.SCHEDULE_STATUS
	
	# Create the milestone if it's new.  Limit with search but then then do an
	# exact match for more accuracy.
	findOrCreateMilestone: (projectId, name) ->
		{ data } = await @client.get "/projects/#{projectId}/milestones", params:
			search: name
		milestones = data.filter (milestone) -> milestone.title == name
		return milestones[0] if milestones.length
		{ data } = await @client.post "/projects/#{projectId}/milestones",
			title: name
		return data
	
	# Get the issue record form it's URL
	getIssueFromUrl: (projectId, url) ->
		id = url.match(/(\d+)$/)[1]
		{ data } = await @client.get "/projects/#{projectId}/issues/#{id}"
		return data
		
	# Get all of the asana links in the description
	# https://regex101.com/r/QMTHro/1
	getAsanaTaskIds: (description) ->
		regex = /https:\/\/app.asana.com\/\d+\/\d+\/(\d+)/g
		ids = []
		ids.push match[1] while match = regex.exec description
		return ids