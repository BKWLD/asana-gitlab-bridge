# Asana Gitlab Bridge

Opinionated self-hosted tool that keeps GitLab in sync with Asana.  Uses Contentful as a CMS to setup the mapping between Asana and GitLab projects.  Uses Slack to deliver notifications that an estimate is requested.

## How it works

1. Admin logs into Contentful and creates a new "Map" by selecting a Asana project and GitLab project from pulldown menus.
2. A new issue is created in Asana.
3. The issue is given a status of "Estimating", which triggers a Slack notification that an estimate is requested for an Asana task.
4. The estimator logs into Asana and adds a time estimate to the task.
5. The issues status is automatically changed to "Estimated" by the bridge.
6. An Asana user moves the issue to a milestone section.
7. The bridge automatically creates a GitLab issue for the Asana task, including a link back to the Asana task.
8. When the GitLab issue is closed, the bridge automatically closes the Asana task.