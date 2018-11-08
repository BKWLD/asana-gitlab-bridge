# Deps
# asana = new (require '../../services/asana')
# contentful = new (require '../../services/contentful')
# slack = new (require '../../services/slack')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Force async/await mode
	await Promise.resolve()
	
	console.log JSON.stringify request

	# Return success
	statusCode: 200
