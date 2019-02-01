# Deps
axios = require 'axios'
_ = require 'lodash'
asana = new (require './asana')
db = new (require './db')

# Define the service
module.exports = class Slack
	
	# Build Slack client
	constructor: -> @client = axios.create
		baseURL: 'https://slack.com/api'
		headers: Authorization: "Bearer #{process.env.SLACK_ACCESS_TOKEN}"
	
	# Post a Slack message to the channel asking for an estimate on the task
	sendEstimateRequestForTask: (channel, task) ->
		meta = await asana.getMeta task
		{ data } = await @client.post 'chat.postMessage',
			channel: channel
			text: '⏱ Time estimate needed for this task:'
			username: 'Asana + GitLab bridge'
			icon_url: 'http://yo.bkwld.com/ae5f50ff27b9/asana-logo.png'
			attachments: [
				{ # The task body
					title: task.name
					title_link: meta.url
					text: task.notes
					ts: Math.round new Date(task.created_at).getTime()/1000
					author_name: meta.author.name
					author_link: meta.author.url
					author_icon: meta.author.icon
				}
				{ # Meta type data
					text: ''
					fields: [
						{ title: 'Priority', value: meta.priority, short: true } if meta.priority
						{ title: 'Comments', value: meta.comments, short: true }
					]
				}
				{ # The actions links
					color: '#f05076'
					text: ''
					callback_id: task.id
					actions: [
						{ type: 'button', text: 'View Asana task', url: meta.url }
						{
							name: 'estimate'
							text: 'Enter estimate'
							type: 'select'
							options: do -> for i in [1..40]
								text: "#{i} hours"
								value: i
						}
					]
				}
			]
		
		# Log the ts of the message so it can be deleted when the task is estimated
		db.put asana.estimateMessageKey(task), 
			channelId: data.channel
			messageId: data.ts
	
	# Create the success slack message after a message is submitted
	replaceEstimateRequestWithSuccess: (channelId, messageId, task) ->

		# Update the message
		await @client.post 'chat.update', 
			@buildEstimateSuccessMessage channelId, messageId, task

		# Remove the old key
		await db.delete asana.estimateMessageKey task
	
	# Build the estimate success message
	buildEstimateSuccessMessage: (channelId, messageId, task, hours = null) ->
		
		# Muster data
		url = asana.taskUrl task
		hours = asana.customFieldValue task, asana.ESTIMATE_FIELD unless hours
		
		# Return object
		channel: channelId
		ts: messageId
		text: "🍻 <#{url}|#{task.name}> was estimated at *#{hours} hours*."
		attachments: [] # Clear the attachments