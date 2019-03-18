###
See if mergeIssues results in what is expected
###
gitlab = new (require '../../functions/services/gitlab')
issue = require './issue.json'
console.log gitlab.mergeLabels issue, [ 'Critical' ]