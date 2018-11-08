# Deps
asana = new (require '../../services/asana')
contentful = new (require '../../services/contentful')
slack = new (require '../../services/slack')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Force async/await mode
	await Promise.resolve()
	
	# Loop through task events
	body = JSON.parse request.body
	events = (body?.events || []).filter (event) -> event.type == 'task'
	for event in events
		
		# Lookup the task
		if task = await asana.findTask event.resource

			# If in estimating phase, trigger notification
			if asana.hasStatus task, asana.ESTIMATE_STATUS
				console.debug "Sending estimate request"
				entry = await contentful.findEntry request.queryStringParameters.entry
				channel = contentful.field entry, 'slackChannel'
				await slack.sendEstimateRequestForTask channel, task

	# Return success
	statusCode: 200
	headers: 'X-Hook-Secret': request.headers['X-Hook-Secret']
