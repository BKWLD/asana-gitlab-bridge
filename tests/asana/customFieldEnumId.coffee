###
Test updateEnumCustomField
###
asana = new (require '../../functions/services/asana')
task = require './task.json'
console.log asana.customFieldEnumId task, asana.DEPLOYED_STATUS, null