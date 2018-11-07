# Deps
contentful = new (require '../../services/contentful')

# Build list of platforms that can be looped through
platforms = 
	asana: new (require '../../services/asana')
	gitlab: new (require '../../services/gitlab')

# Handle Asana webhooks
module.exports = (request) ->
	
	# Force Lambda to use async/await mode
	await Promise.resolve()
	
	# Get the current and previos entries
	entry = JSON.parse request.body
	last = await contentful.lastSnapshot contentful.id entry
	
	# Update per-project webhooks for each platform
	for name, client of platforms
		projectId = contentful.field entry, "#{name}Project"
		lastProjectId = contentful.field last, "#{name}Project"
		if projectId != lastProjectId
			console.debug "Updating #{name}", projectId, lastProjectId
			await client.deleteWebhook lastProjectId if lastProjectId
			await client.createWebhook projectId

	# Return success
	statusCode: 200