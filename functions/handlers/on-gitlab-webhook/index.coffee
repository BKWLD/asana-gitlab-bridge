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

	# If the issue is closed, complete or deploy all of the asana links in the 
	# description
	payload = JSON.parse request.body
	if payload.object_attributes.action == 'close'
		taskIds = gitlab.getAsanaTaskIds payload.object_attributes.description
		for taskId in taskIds
			console.debug "Completing", taskId
			
			# Complete the task
			if process.env.CLOSE_TASK_WHEN_ISSUE_CLOSED == 'true'
				await asana.completeTask taskId
			
			# Mark "deployed"
			if process.env.DEPLOY_TASK_WHEN_ISSUE_CLOSED == 'true'
				task = await asana.getTask taskId
				await asana.updateStatus task, asana.DEPLOYED_STATUS

	# Return success
	statusCode: 200
