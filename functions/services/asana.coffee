axios = require 'axios'

# Define the service
module.exports = class Asana
	
	# Build Axios client
	constructor: -> @axios.create
		baseURL: 'https://app.asana.com/api/1.0'
		headers: Authorization: "Bearer #{process.env.ASANA_ACCESS_TOKEN}"
	# 
	# # Util for accessing key given an entry
	# field: (entry, key) -> entry?.fields?[key]?['en-US']
	# 
	# # Util for getting the id of an entry
	# id: (entry) -> entry?.sys?.id
	# 
	# # Get the last entry
	# lastSnapshot: (entryId) -> 
	# 	{ data } = await @client "/entries/#{entryId}/snapshots", parms:
	# 		order: 'sys.updatedAt'
	# 		limit: 1
	# 		skip: 1
	# 	return data?.items?[0]?.snapshot