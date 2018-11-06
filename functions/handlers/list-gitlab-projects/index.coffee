axios = require 'axios'
_ = require 'lodash'

# Make Asana client
client = axios.create
	baseURL: 'https://gitlab.com/api/v4'
	headers: 'Private-Token': process.env.GITLAB_ACCESS_TOKEN

# Return list of Asana projects
module.exports = (request) ->
	
	# Recursively get all the projects in all of the subgroups
	{ data } = await client.get "/projects?membership=1&per_page=100"
	projects = data.map (project) ->
		id: project.id
		name: project.name_with_namespace 
	projects = _.sortBy projects, 'name'
	
	# Return success
	statusCode: 200
	headers: 'Access-Control-Allow-Origin': '*'
	body: JSON.stringify projects
	