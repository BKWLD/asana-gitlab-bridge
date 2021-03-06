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
	
	# Get array of label titles
	labels = payload.labels.map (label) -> label.title
	
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
				
				# Add the "Deployed" label so that the subsequent "Sync labels" step
				# will write it to GitLaba and to Asana
				if process.env.DEPLOY_TASK_WHEN_ISSUE_CLOSED == 'true'
					labels.push asana.DEPLOYED_STATUS
					
		# Update labels at Asana
		console.debug "Syncing Asana labels", taskId
		normalizedLabels = asana.normalizeLabels labels
		for fieldName, value of normalizedLabels
			
			# If the status has been cleared from GitLab, default it to "Pending" in
			# Asana if it currently has a status label.  In other words, if Asana is
			# set to like "Scheduling", leave it alone.  But if it is set to 
			# "Addressed", then set it to "Pending", which is the effectively the
			# Asana version of a null GitLab status.
			value = asana.PENDING_STATUS if fieldName == asana.STATUS_FIELD and 
			!value and asana.hasStatusLabelOrIsPending(task)
			
			# Set the value
			await asana.updateEnumCustomField task, fieldName, value
	
		# Only keep the foremost labels at GitLab
		console.debug "Syncing GitLab labels", taskId
		mergedLabels = Object.values normalizedLabels
		.concat gitlab.nonSyncingLabels labels
		await gitlab.writeLabels payload.object_attributes, mergedLabels

	# Return success
	statusCode: 200
