# Deps
asana = new (require '../../services/asana')
contentful = new (require '../../services/contentful')
gitlab = new (require '../../services/gitlab')
slack = new (require '../../services/slack')
db = new (require '../../services/db')

# Handle Asana webhooks
module.exports = (request) ->
			
	# Force async/await mode
	await Promise.resolve()
	
	# Lookup the Contentful entry and channel
	entry = await contentful.findEntry request.queryStringParameters.entry
	channel = contentful.field entry, 'slackChannel'
	gitlabProjectId = contentful.field entry, 'gitlabProject'
	
	# Loop through task events
	body = JSON.parse request.body
	events = (body?.events || []).filter (event) -> event.type == 'task'
	for event in events
	
		# Lookup the task.  When moving between sections tasks seem to get new ids
		# and will 404, thus the try/catch here.
		console.debug 'Handling task', event.resource
		try continue unless task = await asana.findTask event.resource
		catch e then console.error 'Task not found', event.resource; continue
		
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

		# If we hvae an estimate but the status is still ON estimate, update it
		if asana.needsScheduleStatus task
			console.debug 'Updating task status', asana.SCHEDULE_STATUS
			await asana.updateStatus task, asana.SCHEDULE_STATUS
		
		# If in the scheduling status and in a section, create the milestone and
		# issue for the issue
		if asana.issueable task
			console.debug 'Creating issue', task.id
			issue = await gitlab.createIssue gitlabProjectId, task
			await asana.addIssue task, issue.web_url
			
		# If issued, sync the section with the Gitlab milestone
		if asana.issued task
			console.debug 'Syncing milestone', task.id
			await gitlab.syncIssueToMilestone gitlabProjectId, task

	# Return success
	statusCode: 200
	headers: 'X-Hook-Secret': request.headers['X-Hook-Secret']
