### Gitflow Branch Gate

This extension adds a build task to help control branch commits, enforce Gitflow conventions and branch limits. Essentially, set your builds on fire if your branching strategy, limits and rules are not followed.

[Gitflow](http://nvie.com/posts/a-successful-git-branching-model/) is a branching model for Git, created by Vincent Driessen. It's a standardised approach that allows teams to separate feature development, release and support for emergency fixes. Sounds amazing right? Well, there are a few gotchas especially when it comes to keeping all branches up to date and making sure conventions are followed.

### The Scenario

Your using the Gitflow branching model, or variation of it, Pull Requests with Team Foundation Server branch policies enabled but need a way to prevent hotfixes\releases from being rolled back! Also, while you're at it, you want to prevent stale branches...

_Introducing the Gitflow Branch Gate build task..._

Keeping branches up to date becomes difficult as the number of developers, requirements or product delivery increases. Many teams try to adopt a trunk based branching strategy, and while this potentially solves many problems, it's not always possible. This build task aims to promote short-lived branches and assist in moving all branches forward.

### Features

- Configure branch naming standards and make sure they are followed
- Apply branch limits to hotfixes, release and feature branches
- Set builds on fire if branches become stale
- Make sure all branches are never behind master
- Make sure all feature branches are never behind develop
- Prevent release & hotfix branches being created at the same time
- Track active Pull Requests from important branches to prevent deployed changes from being rolled back

### Reporting

The extension publishes a summary of the results to the build summary showing all issues:

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/master/Tasks/GitflowBranchGate/images/report-summary-2.png" alt="Report Summary"/>

A detailed log is provided with all rules configured for that build, branches and active Pull Requests at that point in time.

### Branch Limits

Apply branch limits for hotfixes, releases and feature branches:

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/master/Tasks/GitflowBranchGate/images/Limits.png" alt="Branch Limits" style=""/>

### Branch Rules

Apply branch rules for all branches and active Pull Requests:

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/master/Tasks/GitflowBranchGate/images/Rules.png" alt="Rules" style=""/>
