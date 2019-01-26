# Deps
asana = new (require '../../services/asana')
contentful = new (require '../../services/contentful')
gitlab = new (require '../../services/gitlab')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Lookup the Contentful entry
	entry = await contentful.findEntry request.queryStringParameters.entry
	channel = contentful.field entry, 'slackChannel'
	asanaProjectId = contentful.field entry, 'asanaProject'

	# If the issue is closed, complete all of the asana links in the description
	payload = JSON.parse request.body
	if payload.object_attributes.action == 'close' and 
	process.env.CLOSE_TASK_WHEN_ISSUE_CLOSED == 'true'
		taskIds = gitlab.getAsanaTaskIds payload.object_attributes.description
		for taskId in taskIds
			console.debug "Completing", taskId
			await asana.completeTask taskId

	# Return success
	statusCode: 200
