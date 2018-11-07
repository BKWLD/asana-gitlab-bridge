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
	
	# Update per-project webhooks for each platform.  We always delete and create
	# because it's not trivial to detect whether a Contentful publish is the
	# result of creating/changing a project or restoring an archived state.  So
	# we always delete the current one if it exists and then creata anew, event
	# if it means recreating the same one.
	for name, client of platforms
		
		# Lookup IDs
		lastProjectId = contentful.field last, "#{name}Project"
		projectId = contentful.field entry, "#{name}Project"
		
		# Delete previous hook
		if lastProjectId or not projectId
			console.debug "Deleting #{name}", lastProjectId
			await client.deleteWebhook lastProjectId
			
		# Make new hook
		if projectId
			console.debug "Creating #{name}", projectId
			await client.createWebhook projectId

	# Return success
	statusCode: 200