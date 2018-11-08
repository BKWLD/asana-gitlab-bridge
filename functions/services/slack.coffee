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
		
		# Muster data
		url = asana.taskUrl task
		stories = await asana.getTaskStories task.id
		author = await asana.getStoryCreator stories[0] if stories.length
		
		# Make message body
		{ data } = await @client.post 'chat.postMessage',
			channel: channel
			text: '⏱ Time estimate needed for this task:'
			username: 'Asana + GitLab bridge'
			icon_url: 'http://yo.bkwld.com/ae5f50ff27b9/asana-logo.png'
			attachments: [
				{ # The task body
					title: task.name
					title_link: url
					text: task.notes
					ts: Math.round new Date(task.created_at).getTime()/1000
					author_name: author.name
					author_link: "https://app.asana.com/0/#{author.id}"
					author_icon: author.photo?.image_36x36
				}
				{ # Meta type data
					text: ''
					fields: @buildEstimateTaskFields task, stories
				}
				{ # The actions links
					color: '#f05076'
					text: ''
					callback_id: task.id
					actions: @buildEstimateTaskActions url
				}
			]
		
		# Log the ts of the message so it can be deleted when the task is estimated
		db.put asana.estimateMessageKey(task), 
			channelId: data.channel
			messageId: data.ts
		
	# Build the fields
	buildEstimateTaskFields: (task, stories) ->
		[
			# Ticket priority
			{
				title: 'Priority'
				value: do ->
					label = asana.customFieldValue task, 'Priority'
					emoji = switch label
						when 'Critical' then '📕'
						when 'High' then '📙'
						when 'Medium' then '📒'
						when 'Low' then '📘'
					return "#{emoji} #{label}"
				short: true
			}
			
			# The amount of comments
			{
				title: 'Comments'
				value: do ->
					comments = stories.filter (story) -> story.type == 'comment'
					return "💬 #{comments.length}"
				short: true
			}
		]
	
	# Build the actions array
	buildEstimateTaskActions: (url, stories) ->
		[

			# Link to the task
			{
				type: 'button'
				text: 'View Asana task'
				url: url
			}
			
			# The list of hours to choose from
			{
				name: 'estimate'
				text: 'Enter estimate'
				type: 'select'
				options: do -> for i in [1..40]
					text: "#{i} hours"
					value: i
			}
		]
	
	# Create the success slack message after a message is submitted
	replaceEstimateRequestWithSuccess: (channelId, messageId, task) ->
		
		# Muster data
		url = asana.taskUrl task
		hours = asana.customFieldValue task, asana.ESTIMATE_FIELD

		# Update the message
		await @client.post 'chat.update',
			channel: channelId
			ts: messageId
			text: "🍻 <#{url}|#{task.name}> has been estimated at *#{hours} hours*."
			attachments: [] # Clear the attachments

		# Remove the old key
		await db.delete asana.estimateMessageKey task