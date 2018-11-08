# Deps
asana = new (require '../../services/asana')
contentful = new (require '../../services/contentful')
slack = new (require '../../services/slack')
db = new (require '../../services/db')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Force async/await mode
	await Promise.resolve()
	
	# Lookup the Contentful entry and channel
	entry = await contentful.findEntry request.queryStringParameters.entry
	channel = contentful.field entry, 'slackChannel'
	
	# Loop through task events
	body = JSON.parse request.body
	events = (body?.events || []).filter (event) -> event.type == 'task'
	for event in events
	
		# Lookup the task
		continue unless task = await asana.findTask event.resource

		# If in estimating phase, trigger notification
		if await asana.needsEstimateAndNotSent task
			console.debug "Sending estimate request"
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

	# Return success
	statusCode: 200
	headers: 'X-Hook-Secret': request.headers['X-Hook-Secret']
