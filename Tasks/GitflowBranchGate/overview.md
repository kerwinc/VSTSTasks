This extension adds a build task help control branch commits, enforce Gitflow conventions and branch limits. Essentially, set everything on fire if your branching strategy is not followed.

[Gitflow](http://nvie.com/posts/a-successful-git-branching-model/) is a branching model for Git, created by Vincent Driessen. It's a standardised approach that allows teams to separate feature development, release and support for emergency fixes. Sounds amazing right? Well, there are a few gotchas especially when it comes to keeping all branches up to date and making sure conventions are followed.

### The Scenario:

Your using the Gitflow branching model, or variation of it, Pull Requests with Team Foundation Server branch policies switched on but need a way to prevent hotfixes\releases from being rolled back! Also, while you're at it, you want to prevent stale branches...

*Introducing the Gitflow Branch Gate build task...*

### Features:
- Configure branch naming standards and make sure they are followed
- Apply branch limits to hotfixes, release and feature branches
- Set builds on fire if branches become stale
- Make sure all branches are never behind master
- Make sure all feature branches are never behind develop
- Prevent release & hotfix branches being created at the same time
- Track active Pull Requests so prevent deployed changes from being rolled back

### Branch Limits

![Branch Limits](https://raw.githubusercontent.com/kerwinc/VSTSTasks/master/Tasks/GitflowBranchGate/images/Limits.png "Gitflow Branch Limits")
