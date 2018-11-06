axios = require 'axios'
_ = require 'lodash'

# Make Asana client
client = axios.create
	baseURL: 'https://gitlab.com/api/v4'
	headers: 'Private-Token': process.env.GITLAB_ACCESS_TOKEN

# Return list of Asana projects
module.exports = (request) ->
	
	# Recursively get all the projects in all of the subgroups
	projects = []
	await getProjectsOfGroup process.env.GITLAB_GROUP, projects
	
	# Alphabetize
	projects = _.sortBy projects, 'name'

	# Return success
	statusCode: 200
	headers: 'Access-Control-Allow-Origin': '*'
	body: JSON.stringify projects
	
# Get projects of a group
getProjectsOfGroup = (group, projects) ->
	
	# Get the projects first
	{ data } = await client.get "/groups/#{group}/projects" 
	for project in data
		projects.push
			id: project.id
			name: project.name_with_namespace 
	
	# Check for subgroups
	{ data } = await client.get "/groups/#{group}/subgroups" 
	await getProjectsOfGroup group.id, projects for group in data
		