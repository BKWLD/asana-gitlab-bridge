# Deps
axios = require 'axios'
_ = require 'lodash'
db = new (require './db')

# Constants that are used in multiple places
PRIORITY_FIELD = 'Priority'
STATUS_FIELD = 'Dev status'
DEPLOYED_STATUS = 'Deployed'

# Define the service
module.exports = class Asana
	
	# Constants for custom field names
	PRIORITY_FIELD: PRIORITY_FIELD
	STATUS_FIELD: STATUS_FIELD
	ESTIMATE_FIELD: 'Est'
	ISSUE_FIELD: 'GitLab'
	
	# Constants for Statuses
	ESTIMATE_STATUS: 'Estimating'
	SCHEDULE_STATUS: 'Scheduling'
	PENDING_STATUS: 'Pending'
	DEPLOYED_STATUS: DEPLOYED_STATUS
	
	# Status lables organized by custom fields and ordered intentionally
	labels:
		"#{PRIORITY_FIELD}": [
			'Critical'
			'High'
			'Medium'
			'Low'
		]
		"#{STATUS_FIELD}": [ # Only those that get synced
			DEPLOYED_STATUS
			'Approved'
			'Staged'
			'Addressed'
		]
		
	# Build Axios client
	constructor: -> @client = axios.create
		baseURL: 'https://app.asana.com/api/1.0'
		headers: Authorization: "Bearer #{process.env.ASANA_ACCESS_TOKEN}"
	
	# Fetch list of projects for access token
	getProjects: ->
		{ data } = await @client.get '/projects'
		projects = data.data.map (project) -> 
			id: project.gid
			name: project.name 
		return _.sortBy projects, 'name'
	
	# Create a webhook for a given project id
	createWebhook: (entryId, projectId) ->
		{ data } = await @client.post '/webhooks', data:
			resource: projectId
			target: "#{process.env.GATEWAY_URL}/asana/webhook?entry=#{entryId}"
		await db.put @webhookKey(entryId), data.data.gid
		
	# Delete a webhook for a given project id
	deleteWebhook: (entryId) -> 
		if webhookId = await db.get @webhookKey entryId
			await @client.delete "/webhooks/#{webhookId}"
			await db.delete @webhookKey entryId
	
	# Make the key for storing webhooks
	webhookKey: (entryId) -> "asana-#{entryId}-webhook-id"

	# Find a task given it's id
	getTask: (id) ->
		{ data } = await @client.get "/tasks/#{id}"
		return data?.data
	
	# Get the count of task stories
	getTaskStories: (id) ->
		{ data } = await @client.get "/tasks/#{id}/stories"
		return data?.data
	
	# Check if the status is a particular status
	hasStatus: (task, status) -> 
		status == @getStatus task, status 
	
	# Check if the status is also a GitLab label or is pendinh
	hasStatusLabelOrIsPending: (task) ->
		@hasStatusLabel(task) or @getStatus(task) == asana.PENDING_STATUS
	
	# Check if the status is also a GitLab label
	hasStatusLabel: (task) -> @getStatus(task) in @labels[@STATUS_FIELD]
			
	# Get the status for a task
	getStatus: (task) -> @customFieldValue task, @STATUS_FIELD
		
	# Get a custom field value
	customFieldValue: (task, fieldName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		return field?.enum_value?.name || field?.number_value || field?.text_value
	
	# Get the id of a custom field
	customFieldId: (task, fieldName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		return field?.gid
		
	# For an enum field, find the id of the particular opion
	customFieldEnumId: (task, fieldName, enumName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		option = field?.enum_options?.find (option) -> option.name == enumName
		return option?.gid || null
		
	# Lookup the creator user of a story (like a note on a task)
	getStoryCreator: (story) ->
		{ data } = await @client.get "/users/#{story.created_by.gid}"
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
	estimateMessageKey: (task) -> "asana-#{task.gid}-estimate-message" 
	
	# Make the URL to a task
	taskUrl: (task) -> "https://app.asana.com/0/0/#{task.gid}"
	
	# Update the status custom field
	updateStatus: (task, status) ->
		@updateEnumCustomField task, @STATUS_FIELD, status
	
	# Update the status custom field
	updatePriority: (task, priority) ->
		@updateEnumCustomField task, @PRIORITY_FIELD, priority
			
	# Update an enum custom value
	updateEnumCustomField: (task, fieldName, value) ->
		fieldId = @customFieldId task, fieldName
		valueId = @customFieldEnumId task, fieldName, value
		@client.put "/tasks/#{task.gid}", data:
			custom_fields: "#{fieldId}": valueId
			
	# Update the status custom field
	updateEstimate: (task, hours) ->
		fieldId = @customFieldId task, @ESTIMATE_FIELD
		@client.put "/tasks/#{task.gid}", data:
			custom_fields: "#{fieldId}": hours 
			
	# A task is ticketable if it is in a milestone-like section but doesn't have
	# an issue yet and isn't named like a milestone (Asana will return sections
	# like tasks)
	issueable: (task) -> 
		@inMilestone(task) and 
		not @issued(task) and 
		task.name and # Has a name
		not @namedLikeMilestone(task.name) and
		not @hasStatus(task, @ESTIMATE_STATUS)
	
	# Add a issue reference to Asana
	addIssue: (task, issueUrl) ->
		fieldId = @customFieldId task, @ISSUE_FIELD
		@client.put "/tasks/#{task.gid}", data:
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
		stories = await @getTaskStories task.gid
		author = await @getStoryCreator stories[0] if stories.length
		
		# Return payload
		url: url
		author: 
			name: author.name
			url: "https://app.asana.com/0/#{author.gid}"
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
	
	# Make an array of the active value of "label" custom fields
	getLabels: (task) ->
		Object.keys(@labels).map (fieldName) =>

			# Get the value of the field and return it if it's one of the values that
			# get synced with GitLab
			if value = @customFieldValue task, fieldName	
				if value in @labels[fieldName]
					return value
			
		# Remove labels that were empty
		.filter (label) -> !!label
	
	# Get a list of all the labels that are synced
	syncedLabels: -> 
		Object.values(@labels).reduce (all, labels) -> all.concat labels
		, []
	
	# Take an array of labels from GitLab and return an object with keys for each
	# fieldName and only one 
	normalizeLabels: (labels) ->
		
		# Open a chain
		_(labels)
		
		# Group the incoming labels by Asana custom field names
		.groupBy (label) =>
			for fieldName, options of @labels
				return fieldName if label in options
			return '' # Default
		
		# Remove null keys; these are labels that don't get synced to Asana
		.pickBy (labels, fieldName) -> !!fieldName
		
		# Reduce the labels to the highest priority or latest lifecycle label
		# in the first index
		.mapValues (labels, fieldName) =>
			_(labels).orderBy (label) => @labels[fieldName].indexOf label
			.first()
			
		# Set emtpy strings for any fieldNames that weren't present in the list of
		# labels so the value will clear if the label was removed in GitLab
		.defaults _.mapValues @labels, -> null
		
		# Return final object
		.value()