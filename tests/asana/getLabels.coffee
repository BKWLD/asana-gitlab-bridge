###
See what labels are found for a task
###
asana = new (require '../../functions/services/asana')
task = require './task.json'
console.log asana.getLabels task