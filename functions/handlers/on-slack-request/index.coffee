# Deps
querystring = require 'querystring'
asana = new (require '../../services/asana')
slack = new (require '../../services/slack')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Force async/await mode
	await Promise.resolve()
	
	# Get the payload
	payload = JSON.parse (querystring.parse request.body).payload
	taskId = payload.callback_id
	
	# Lookup the task
	task = await asana.findTask taskId
	
	# Set the estimate on the task
	hours = payload.actions[0].selected_options[0].value
	await asana.updateEstimate task, hours
	
	# Return success and udpate the message
	statusCode: 200
	headers: 'Content-Type': 'application/json'
	body: JSON.stringify Object.assign {},
		replace_original: true,
		slack.buildEstimateSuccessMessage payload.channel.id, 
			payload.message_ts, task, hours