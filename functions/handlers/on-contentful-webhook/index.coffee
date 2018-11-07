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
	
	# Get the current entry
	entry = JSON.parse request.body
	entryId = contentful.id entry
	
	# Update per-project webhooks for each platform.  We always delete and create
	# because it's cleaner and this won't be called much.
	for name, client of platforms
		
		# Delete old hook
		console.debug "Deleting #{name}", entryId
		await client.deleteWebhook entryId
			
		# Make new hook
		if projectId = contentful.field entry, "#{name}Project"
			console.debug "Creating #{name}", projectId
			await client.createWebhook entryId, projectId

	# Return success
	statusCode: 200