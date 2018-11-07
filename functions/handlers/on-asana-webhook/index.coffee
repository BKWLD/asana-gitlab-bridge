axios = require 'axios'

# Handle Asana webhooks
module.exports = (request) ->
	
	console.log JSON.stringify request
	
	# Force async/await mode
	await Promise.resolve()

	# Return success
	statusCode: 200
	headers: 'X-Hook-Secret': request.headers['X-Hook-Secret']
