# Deps
asana = new (require '../../services/asana')
contentful = new (require '../../services/contentful')
gitlab = new (require '../../services/gitlab')
slack = new (require '../../services/slack')
db = new (require '../../services/db')
_ = require 'lodash'

# Handle Asana webhooks
module.exports = (request) ->
	
	# Lookup the Contentful entry and channel
	entry = await contentful.findEntry request.queryStringParameters.entry
	channel = contentful.field entry, 'slackChannel'
	gitlabProjectId = contentful.field entry, 'gitlabProject'
	
	# Get all the unique task ids from the events list
	# https://stackoverflow.com/a/14438954/59160
	body = JSON.parse request.body
	taskIds = (body?.events || [])
	
		# Suppot the old (event.type) and new (event.resource.resource_type) schemas
		.filter (event) -> (event.type || event.resource.resource_type) == 'task'
		
		# Support the old (event.resource) and new (event.resource.gid)
		.map (event) -> 
			if _.isObject event.resource
			then event.resource.gid 
			else event.resource
		
		# Dedupe
		# https://stackoverflow.com/a/14438954/59160
		.filter (taskId, index, self) -> self.indexOf(taskId) == index
		
	# Loop through task events
	for taskId in taskIds
	
		# Lookup the task.  When moving between sections tasks seem to get new ids
		# and will 404, thus the try/catch here.
		console.debug 'Handling task', taskId
		try continue unless task = await asana.getTask taskId
		catch e then console.error 'Task not found', taskId; continue
		
		# Don't do anything with completed tasks
		continue if task.completed
		
		# Don't do anything if there is no dev status
		continue unless asana.customFieldValue task, asana.STATUS_FIELD
		
		# If in estimating phase, trigger notification
		if await asana.needsEstimateAndNotSent task
			console.debug 'Sending estimate request'
			await slack.sendEstimateRequestForTask channel, task

		# If we don't need an estimate but the slack notification hasn't been 
		# updated to show success, do that now.
		if message = await asana.getEstimateMessageIfEstimateComplete task
			{ channelId, messageId } = message
			console.debug 'Updating estimate message', channelId, messageId
			await slack.replaceEstimateRequestWithSuccess channelId, messageId, task

		# If we have an estimate but the status is still ON estimate, update it
		if asana.needsScheduleStatus task
			console.debug 'Updating task status', asana.SCHEDULE_STATUS
			await asana.updateStatus task, asana.SCHEDULE_STATUS
		
		# If in the scheduling status and in a section, create the milestone and
		# issue for the issue
		if asana.issueable task
			console.debug 'Creating issue', task.id
			issue = await gitlab.createIssue gitlabProjectId, task
			await asana.addIssue task, issue.web_url
			await asana.updateStatus task, asana.PENDING_STATUS
			
		# If issued, sync the section with the Gitlab milestone and sync the labels
		if asana.issued task
			console.debug 'Updating issue', task.id
			issue = await gitlab.getIssueFromUrl gitlabProjectId,
				asana.customFieldValue task, asana.ISSUE_FIELD
			await gitlab.setOrClearMilestone issue, task
			await gitlab.mergeAndWriteLabels issue, asana.getLabels task
				
	# Return success
	statusCode: 200
	headers: 'X-Hook-Secret': request.headers['X-Hook-Secret']
