# Deps
axios = require 'axios'
_ = require 'lodash'
db = new (require './db')

# Define the service
module.exports = class Asana
	
	# Constants for custom field names
	STATUS_FIELD: 'Dev status'
	ESTIMATE_FIELD: 'Est'
	PRIORITY_FIELD: 'Priority'
	ISSUE_FIELD: 'Issue'
	
	# Constatnts for Statuses
	ESTIMATE_STATUS: 'Estimating'
	SCHEDULE_STATUS: 'Scheduling'
	PENDING_STATUS: 'Pending'
	
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
	createWebhook: (entryId, projectId) ->
		{ data } = await @client.post '/webhooks', data:
			resource: projectId
			target: "#{process.env.GATEWAY_URL}/asana/webhook?entry=#{entryId}"
		await db.put @webhookKey(entryId), data.data.id
		
	# Delete a webhook for a given project id
	deleteWebhook: (entryId) -> 
		if webhookId = await db.get @webhookKey entryId
			await @client.delete "/webhooks/#{webhookId}"
			await db.delete @webhookKey entryId
	
	# Make the key for storing webhooks
	webhookKey: (entryId) -> "asana-#{entryId}-webhook-id"

	# Find a task given it's is resouce id
	findTask: (resourceId) ->
		{ data } = await @client.get "/tasks/#{resourceId}"
		return data?.data
	
	# Get the count of task stories
	getTaskStories: (resourceId) ->
		{ data } = await @client.get "/tasks/#{resourceId}/stories"
		return data?.data
	
	# Check if the status is a particular status
	hasStatus: (task, status) -> 
		status == @getStatus task, status 
	
	# Get the status for a task
	getStatus: (task) -> @customFieldValue task, @STATUS_FIELD
		
	# Get a custom field value
	customFieldValue: (task, fieldName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		return field?.enum_value?.name || field?.number_value || field?.text_value
	
	# Get the id of a custom field
	customFieldId: (task, fieldName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		return field?.id
		
	# For an enum field, find the id of the particular opion
	customFieldEnumId: (task, fieldName, enumName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		option = field?.enum_options?.find (option) -> option.name == enumName
		return option?.id
		
	# Lookup the creator user of a story (like a note on a task)
	getStoryCreator: (story) ->
		{ data } = await @client.get "/users/#{story.created_by.id}"
		return data.data
	
	# Check if the task is in the estimating phase but has no estimate
	needsEstimate: (task) ->
		@hasStatus(task, @ESTIMATE_STATUS) and 
			not @customFieldValue(task, @ESTIMATE_FIELD)
	
	# Check if we need and estimate and a message hasn't already been sent
	needsEstimateAndNotSent: (task) ->
		@needsEstimate(task) and not await db.get @estimateMessageKey(task)
		
	# Check if the estimate message can be updated from slack
	getEstimateMessageIfEstimateComplete: (task) ->
		return if @needsEstimate task
		return await db.get @estimateMessageKey(task)
	
	# If we hvae an estimate but the status is still ON estimate
	needsScheduleStatus: (task) ->
		@hasStatus(task, @ESTIMATE_STATUS) and 
			@customFieldValue(task, @ESTIMATE_FIELD)
	
	# Build the key used to keep track of the estimate notification
	estimateMessageKey: (task) -> "asana-#{task.id}-estimate-message" 
	
	# Make the URL to a task
	taskUrl: (task) -> "https://app.asana.com/0/0/#{task.id}"
	
	# Update the status custom field
	updateStatus: (task, status) ->
		fieldId = @customFieldId task, @STATUS_FIELD
		statusId = @customFieldEnumId task, @STATUS_FIELD, status
		@client.put "/tasks/#{task.id}", data:
			custom_fields: "#{fieldId}": statusId 
			
	# Update the status custom field
	updateEstimate: (task, hours) ->
		fieldId = @customFieldId task, @ESTIMATE_FIELD
		@client.put "/tasks/#{task.id}", data:
			custom_fields: "#{fieldId}": hours 
			
	# A task is ticketable if it is in a milestone-like section but doesn't have
	# an issue yet and isn't named like a milestone (Asana will return sections
	# like tasks)
	issueable: (task) -> 
		@inMilestone(task) and 
		not @issued(task) and 
		task.name and # Has a name
		not @namedLikeMilestone(task.name)
	
	# Add a issue reference to Asana
	addIssue: (task, issueUrl) ->
		fieldId = @customFieldId task, @ISSUE_FIELD
		@client.put "/tasks/#{task.id}", data:
			custom_fields: "#{fieldId}": issueUrl 
		
	# Has the task had a issue created for it?
	issued: (task) -> !!@customFieldValue task, @ISSUE_FIELD
	
	# Check if a task is in a milestone by seeing if any of it's memberships have
	# a milestone/sprint style name
	inMilestone: (task) -> !!@milestoneName task
	
	# Get the milestone of an issue by looping through the memberships and 
	# getting section ones that match the naming convention.  Trim trailing colon
	# and whitespace from the name.
	milestoneName: (task) ->
		membership = task.memberships.find (membership) =>
			@namedLikeMilestone membership.section?.name
		return membership?.section.name.replace /\s*:\s*$/, ''
	
	# Test if something has a milestone-like name
	namedLikeMilestone: (name) -> name?.match /^(Milestone|Sprint)/i
		
	# Complete a task
	completeTask: (taskId) ->
		@client.put "/tasks/#{taskId}", data: completed: true
	
	# Build meta info on a task
	getMeta: (task) ->
		
		# Muster data
		url = @taskUrl task
		stories = await @getTaskStories task.id
		author = await @getStoryCreator stories[0] if stories.length
		
		# Return payload
		url: url
		author: 
			name: author.name
			url: "https://app.asana.com/0/#{author.id}"
			icon: author.photo?.image_36x36
		priority: switch @customFieldValue task, 'Priority'					
			when 'Critical' then '📕 Critical'
			when 'High' then '📙 High'
			when 'Medium' then '📒 Medium'
			when 'Low' then '📘 Low'
		comments: do ->
			comments = stories.filter (story) -> story.type == 'comment'
			return "💬 #{comments.length}"
		date: '📅 '+(new Date(task.created_at)).toLocaleDateString 'en-US', 
			month:'short'
			day:'numeric'
			year: 'numeric'