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
		{ data: issue } = await @client.post "/projects/#{projectId}/issues",
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
		await @addTimeEstimate issue, 
			asana.customFieldValue task, asana.ESTIMATE_FIELD
		
		# Set the initial milestone
		await @setMilestone issue, task
		
		# Return the issue data
		return issue
		
	# Add the time estimat to the issue automatically
	addTimeEstimate: (issue, hours) ->
		return unless hours
		@client.post "/projects/#{issue.project_id}/issues/#{issue.iid}/time_estimate",
			duration: "#{hours}h"
	
	# Set or clear the milestone on an issue
	setOrClearMilestone: (issue, task) ->
		if asana.inMilestone task
		then @setMilestone issue, task
		else @clearMilestone issue, task
	
	# Set the milestone of an issue
	setMilestone: (issue, task) ->
		name = asana.milestoneName task
		milestone = await @findOrCreateMilestone issue, name
		if issue.milestone?.id != milestone.id
			await @client.put "/projects/#{issue.project_id}/issues/#{issue.iid}",
				milestone_id: milestone.id
			await asana.updateStatus task, asana.PENDING_STATUS
	
	# Clear the milestone of a task and issue
	clearMilestone: (issue, task) ->
		await @client.put "/projects/#{issue.project_id}/issues/#{issue.iid}",
			milestone_id: null
		await asana.updateStatus task, asana.SCHEDULE_STATUS
	
	# Create the milestone if it's new.  Limit with search but then then do an
	# exact match for more accuracy.
	findOrCreateMilestone: (issue, name) ->
		{ data } = await @client.get "/projects/#{issue.project_id}/milestones", 
			params: search: name
		milestones = data.filter (milestone) -> milestone.title == name
		return milestones[0] if milestones.length
		{ data } = await @client.post "/projects/#{issue.project_id}/milestones",
			title: name
		return data
		
	# Merge and then write labels that came from Asana
	mergeAndWriteLabels: (issue, labels) ->
		@writeLabels issue, @mergeLabels issue, labels
	
	# Combine the normalized labels with any existing, non-syncing labels
	mergeLabels: (issue, labels) -> 
		labels = Object.values asana.normalizeLabels labels
		.concat @nonSyncingLabels issue.labels
	
	# Keep only the labels that don't sync
	nonSyncingLabels: (labels) ->
		labels.filter (label) -> label not in asana.syncedLabels()
	
	# Write the array of labels to the referenced project
	writeLabels: (issue, labels) ->
		await @client.put "/projects/#{issue.project_id}/issues/#{issue.iid}",
			labels: labels.join ','
	
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