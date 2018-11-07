# Deps
gitlab = new (require '../../services/gitlab')

# Return list of GitLab projects
module.exports = (request) ->
	statusCode: 200
	headers: 'Access-Control-Allow-Origin': '*'
	body: JSON.stringify await gitlab.getProjects()
	