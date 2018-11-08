# Deps
axios = require 'axios'

# Define the service
module.exports = class Contentful
	
	# Build Axios client
	constructor: -> @client = axios.create 
		baseURL: "https://api.contentful.com/\
			spaces/#{process.env.CONTENTFUL_SPACE_ID}/\
			environments/master"
		headers: 
			Authorization: "Bearer #{process.env.CONTENTFUl_ACCESS_TOKEN}"
			'Content-Type': 'application/vnd.contentful.management.v1+json'
	
	# Util for accessing key given an entry
	field: (entry, key) -> entry?.fields?[key]?['en-US']
	
	# Util for getting the id of an entry
	id: (entry) -> entry?.sys?.id
	
	# Find an entry by it's id
	findEntry: (entryId) -> 
		{ data } = await @client "/entries/#{entryId}"
		return data
	
	# Get the last version of the entry
	lastSnapshot: (entryId) -> 
		{ data } = await @client "/entries/#{entryId}/snapshots", params:
			order: 'sys.updatedAt'
			limit: 1
			skip: 1
		return data?.items?[0]?.snapshot