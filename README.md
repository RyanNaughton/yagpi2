## YAGPI2 (Yet Another GitHub - Pivotal Integration)

I did a lot of Googling and found about three dozen different ways to connect GitHub and Pivotal Tracker. This includes very popular choices like the Pivotal Tracker GitHub webhook and Zapier.

## Workflow Automation

#### Automating the PR-Pivotal Workflow

YAGPI2 was created to automate the PR-Pivotal workflow as follows:

* A pull request is made in a repository, where the PR either (a) has a branch with the Pivotal ID in the branch name or (b) the PR states the Pivotal ID in the description. When that happens, (1) the story associated with that ID is then marked "Finished" and (2) the URL to the PR should be posted as a comment. (If the user forgets the ID, the API will automatically nag them as a PR comment.)

* A pull request is merged. The story associated with the ID in that PR is then marked "Delivered".

Because many of our tasks don't involve deploying, we don't have to worry about continuous integration or any of that.


#### Automating Issues

Additionally, YAGPI will automatically mirror GitHub issues on Pivotal:

* Whenever an issue is filed in the repo, a Pivotal story will be created.  That Pivotal story will be a bug, will be a part of an epic titled "Bugs", and will be tagged with the label "triage" (which indicates for a PM to manually file it as P1, P2, or P3).  The Pivotal story will contain the URL of the GitHub issue in the story description and then the GitHub issue will be commented on with the URL of the Pivotal story.

* When the GitHub issue is closed, the associated story is Delivered.


## Installation

1.) Clone this repo.
2.) Host YAGPI on a server.
3.) Set up a GitHub webhook to connect to `/api/v1/github_hook` on your hosted domain. The webhook should receive "Pull Request".


## Customization

Currently YAGPI2 will only implement our rigid workflow, but customization can be added upon request.  You could also fork the repo to change it to implement your own workflow.