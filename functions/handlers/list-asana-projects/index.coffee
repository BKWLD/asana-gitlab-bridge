axios = require 'axios'
_ = require 'lodash'

# Make Asana client
client = axios.create
	baseURL: 'https://app.asana.com/api/1.0'
	headers: Authorization: "Bearer #{process.env.ASANA_ACCESS_TOKEN}"

# Return list of Asana projects
module.exports = (request) ->
	
	# Get list
	response = await client.get '/projects'
	projects = response.data.data.map (project) ->
		id: project.id
		name: project.name 
	projects = _.sortBy projects, 'name'

	# Return success
	statusCode: 200
	headers: 'Access-Control-Allow-Origin': '*'
	body: JSON.stringify projects