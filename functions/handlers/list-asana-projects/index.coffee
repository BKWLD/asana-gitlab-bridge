# Deps
asana = new (require '../../services/asana')

# Return list of Asana projects
module.exports = (request) ->
	statusCode: 200
	headers: 'Access-Control-Allow-Origin': '*'
	body: JSON.stringify await asana.getProjects()