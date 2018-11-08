# Deps
axios = require 'axios'
_ = require 'lodash'
asana = new (require './asana')

# Define the service
module.exports = class Slack
	
	# Build Axios client
	constructor: -> @client = axios.create()
	
	# Lookup the estimate 
	sendEstimateRequestForTask: (channel, task) ->
		
		# Muster some data
		url = "https://app.asana.com/0/0/#{task.id}"
		stories = await asana.getTaskStories task.id
		
		# Make message body
		@client.post process.env.SLACK_INCOMING_WEBHOOK,
			channel: channel
			text: '🕑 Time estimate needed for:'
			username: 'Asana + GitLab bridge'
			icon_url: 'http://yo.bkwld.com/ae5f50ff27b9/asana-logo.png'
			attachments: [
				
				# The task body
				{
					title: task.name
					title_link: url
					text: task.notes
					ts: Math.round new Date(task.created_at).getTime()/1000
				}
				
				# Meta type data
				{
					fields: [
						
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
				}
				{
					color: '#9479af'
					actions: [
						
						# Link to the task
						{
							type: 'button'
							text: 'View Asana task'
							url: url
							color: '#9479af'
						}
						
						# The list of hours to choose from
						{
							name: 'estimate'
							text: 'Enter estimate'
							type: 'select'
							color: '#9479af'
							options: do -> for i in [1..40]
								text: "#{i} hours"
								value: i
						}
					]
				}
			]
