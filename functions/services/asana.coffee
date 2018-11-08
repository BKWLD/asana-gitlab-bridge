# Deps
axios = require 'axios'
_ = require 'lodash'
db = new (require './db')

# Define the service
module.exports = class Asana
	
	# Constants for custom field names
	STATUS_FIELD: 'Bridge status'
	ESTIMATE_FIELD: 'Estimate'
	PRIORITY_FIELD: 'Priority'
	
	# Constatnts for Statuses
	ESTIMATE_STATUS: 'Estimating'
	SCHEDULE_STATUS: 'Scheduling'
	
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
		return field?.enum_value?.name
	
	# Get the id of a custom field
	customFieldId: (task, fieldName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		return field?.id
		
	# For an enum field, find the id of the particular opion
	customFieldEnumId: (task, fieldName, enumName) ->
		field = task.custom_fields.find (field) -> field.name == fieldName
		field.enum_options.find (option) -> option.name == enumName
		return enumName?.name
		
	# Lookup the creator user of a story (like a note on a task)
	getStoryCreator: (story) ->
		{ data } = await @client.get "/users/#{story.created_by.id}"
		return data.data
	
	# Check if the task is in the estimating phase but has no estimate
	needsEstimate: (task) ->
		@hasStatus(task, @ESTIMATE_STATUS) and 
			not @customFieldValue(task, @ESTIMATE_FIELD)
	
	# Build the key used to keep track of the estimate notification
	estimateMessageKey: (task) -> "asana-#{task.id}-estimate-message" 
	
	# Make the URL to a task
	taskUrl: (task) -> "https://app.asana.com/0/0/#{task.id}"
	
	# Update the status custom field
	updateStatus: (task, status) ->
		fieldId = @customFieldId task, @STATUS_FIELD
		statusId = @customFieldEnumId task, @STATUS_FIELD, status
		@client.put "/tasks/#{task.id}", data:
			custom_fields[fieldId] = statusId 