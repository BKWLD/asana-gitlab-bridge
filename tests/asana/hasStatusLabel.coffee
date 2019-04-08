###
See if hasStatusLabel works as expected
###
asana = new (require '../../functions/services/asana')
task = require './task.json'

# Should be false because "pending" isn't a status label
console.log asana.hasStatusLabel task

# Should be true after hacking setting it to Staged
task.custom_fields[0].enum_value.name = 'Staged'
console.log asana.hasStatusLabel task