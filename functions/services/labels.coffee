###
The labels/statuses that get synced by the bridge.  There may be other statuses
but only these are shared between both platforms.
###
module.exports =
	
	priorities: [
		'Low'
		'Medium'
		'High'
		'Critical'
	]
	
	statuses: [
		'Addressed'
		'Staged'
		'Approved'
		'Deployed'
	]