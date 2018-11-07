# Deps
contentful = new (require '../../services/contentful')
asana = new (require '../../services/asana')

# Handle Asana webhooks
module.exports = (request) ->
	
	# Parse the entry
	entry = JSON.parse request.body
	asanaProjectId = contentful.field entry, 'asanaProject'
	gitlabProjectId = contentful.field entry, 'gitlabProject'
	
	# Get the old project ids
	last = await contentful.lastSnapshot contentful.id entry
	lastAsanaProjectId = contentful.field last, 'asanaProject'
	lastGitlabProjectId = contentful.field last, 'gitlabProject'
	
	# If the project id changed, delete the old webhook and recreate
	if asanaProjectId != lastAsanaProjectId
		# asana.deleteWebhook lastAsanaProjectId
		asanaCreateWebhook asanaProjectId
	
	# Force async/await mode
	await Promise.resolve()

	# Return success
	statusCode: 200
