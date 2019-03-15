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

	# Only deal with issues
	payload = JSON.parse request.body
	return unless payload.object_kind == 'issue'
	
	# Loop through all taskIds found in the description
	taskIds = gitlab.getAsanaTaskIds payload.object_attributes.description
	for taskId in taskIds
		
		# Lookup the task
		task = await asana.getTask taskId

		# If the issue is closed, complete the task or set deploy status
		if payload.object_attributes.action == 'close'
				console.debug "Closing", taskId
				
				# Complete the task
				if process.env.CLOSE_TASK_WHEN_ISSUE_CLOSED == 'true'
					await asana.completeTask taskId
				
				# Mark "deployed"
				if process.env.DEPLOY_TASK_WHEN_ISSUE_CLOSED == 'true'
					await asana.updateStatus task, asana.DEPLOYED_STATUS
					# Also update Gitlab to keep in sync 

		# Sync labels
		if (labels = payload.labels) and labels.length
			console.debug "Syncing labels", taskId
			normalizedLabels = asana.normalizeLabels labels.map (label) -> label.title
			
			# Update labels at Asana
			for fieldName, value of normalizedLabels
				await asana.updateEnumCustomField task, fieldName, value
		
			# Only keep the foremost label at GitLab

	# Return success
	statusCode: 200
