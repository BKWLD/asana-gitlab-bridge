// Boot Coffeescript
require('coffeescript/register')

// Expose handlers
module.exports = {
	listAsanaProjects: require('./handlers/list-asana-projects/index.coffee'),
	listGitlabProjects: require('./handlers/list-gitlab-projects/index.coffee'),
	onAsanaWebhook: require('./handlers/on-asana-webhook/index.coffee'),
	onContentfulWebhook: require('./handlers/on-contentful-webhook/index.coffee')
}
