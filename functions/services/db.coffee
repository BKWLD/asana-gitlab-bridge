# Deps
AWS = require 'aws-sdk'

# Simplify simple store, find, and delete calls to DynamoDB
module.exports = class DB
	
	# Build the DB instance
	constructor: -> @client = new AWS.DynamoDB.DocumentClient()
	
	# Store a key/value pair
	put: (key, value) -> 
		await @client.put 
			TableName: process.env.DB
			Item:
				key: key
				value: value
		.promise()
	
	# Find the value given a key
	get: (key) ->
		{ Item } = await @client.get 
			TableName: process.env.DB
			Key: key: key
		.promise()
		return Item?.value
	
	# Delete a key/value pair
	delete: (key) ->
		{ Item } = await @client.delete 
			TableName: process.env.DB
			Key: key: key
		.promise()