###
Verify the labels are normalized as expected
###
asana = new (require '../../functions/services/asana')

console.info 'Check that extra fields get removed'
console.debug asana.normalizeLabels [  
		"Medium",
		"Low",
		"Addressed",
		"Staged",
		"Waiting on client"
	]

console.info 'Check that missing fields would get cleared'
console.debug asana.normalizeLabels [  
		"Medium",
	]

console.info 'Check no labels works'
console.debug asana.normalizeLabels []