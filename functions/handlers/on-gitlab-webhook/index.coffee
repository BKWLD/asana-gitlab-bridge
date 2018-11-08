# Deps
asana = new (require '../../services/asana')
# contentful = new (require '../../services/contentful')
# slack = new (require '../../services/slack')

# Handle Asana webhooks
module.exports = (request) ->
		
	# Lookup the Contentful entry
	entry = await contentful.findEntry request.queryStringParameters.entry
	channel = contentful.field entry, 'slackChannel'
	gitlabProjectId = contentful.field entry, 'gitlabProject'

	# Return success
	statusCode: 200
