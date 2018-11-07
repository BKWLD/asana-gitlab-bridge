# Asana Gitlab Bridge

Opinionated, self-hosted tool that keeps GitLab in sync with Asana.  Uses Contentful as a CMS to setup the mapping between Asana and GitLab projects.  Uses Slack to deliver notifications that an estimate is requested.  Uses AWS + Serverless Framework to handle webhooks from services.

## How it works

1. Admin logs into Contentful and creates a new "Map" by selecting a Asana project and GitLab project from pulldown menus.
2. A new issue is created in Asana.
3. The issue is given a status of "Estimating", which triggers a Slack notification that an estimate is requested for an Asana task.
4. The estimator logs into Asana and adds a time estimate to the task.
5. The issues status is automatically changed to "Estimated" by the bridge.
6. An Asana user moves the issue to a milestone section.
7. The bridge automatically creates a GitLab issue for the Asana task, including a link back to the Asana task.
8. When the GitLab issue is closed, the bridge automatically closes the Asana task.

## Setup

1. Duplicate .env.example as .env and populate all fields.  For Contentful, GitLab, and Asana, you can use Personal Access Tokens (see their docs).  For AWS, I followed the Serverless docs in giving the IAM account `AdministratorAccess`.

2. Run `yarn severless deploy` to deploy the AWS Lambdas.  Don't close the terminal, you'll need the `endpoints` in Step 5.

3. Until https://github.com/contentful/contentful-cli/issues/41 is implemented, you'll need to login to Contentful CLI by running: `yarn contentful login`.

4. Run `contentful:create` to create the Contentful extension in your space.

5. Create a contentType called `map` with the following fields.  For the "Appearence" of the Asana and GitLab fields, choose the "Project selector" custom field and paste in the `asana/projects` and `gitlab/projects` URLs from the Serverless output for the "Project list URL". 

	![](http://yo.bkwld.com/8039e7d3b7bb/Image%202018-11-07%20at%209.59.33%20AM.png)
	![](http://yo.bkwld.com/246460d84853/Image%202018-11-07%20at%2010.04.23%20AM.png)

6. Create a Contentful Webhook like this one:

	![](http://yo.bkwld.com/fcd1c63f33f9/Image%202018-11-07%20at%201.07.32%20PM.png)

## Known issues

- We're not currently paginating through responses so only the first 100 projects in either platform will show up in select menus in Contentful.
- We're fetching all the projects the user whose access token is used in both platforms.