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
	
	# Lookup the task
	task = await asana.findTask event.resource
	
	# Set the estimate on the task
	# hours = payload.actions[0].selected_options[0].value
	# await asana.updateCustomField task, asana.

	# Return success and remove the message
	statusCode: 200
	headers: 'Content-Type': 'application/json'
	