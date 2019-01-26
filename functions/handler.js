// Boot Coffeescript
require('coffeescript/register')

// Raven wrapping helper helper
var Raven = require('raven'),
	RavenLambdaWrapper = require('serverless-sentry-lib'),
	wrap = function(cb) { return RavenLambdaWrapper.handler(Raven, cb) }

// Expose handlers
module.exports = {
	listAsanaProjects: wrap(require('./handlers/list-asana-projects/index.coffee')),
	listGitlabProjects: wrap(require('./handlers/list-gitlab-projects/index.coffee')),
	onAsanaWebhook: wrap(require('./handlers/on-asana-webhook/index.coffee')),
	onContentfulWebhook: wrap(require('./handlers/on-contentful-webhook/index.coffee')),
	onGitlabWebhook: wrap(require('./handlers/on-gitlab-webhook/index.coffee')),
	onSlackRequest: wrap(require('./handlers/on-slack-request/index.coffee'))
}
