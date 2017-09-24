This extension adds a build task help control branch commits, enforce Gitflow conventions and branch limits. Essentially, set everything on fire if your branching strategy is not followed.

GitFlow is a branching model for Git, created by Vincent Driessen. It's a standardised approach that allows teams to separate feature development, release and support for emergency fixes. Sounds amazing right? Well, there are a few gotchas especially when it comes to keeping all branches up to date and making sure conventions are followed.

*Introducing the Gitflow Branch Gate...*

## Features:
- Configure branch naming standards and make sure they are followed
- Apply branch limits to hotfixes, release and feature branches
- Set builds on fire if branches become stale
- Make sure all branches are never behind master
- Make sure all feature branches are never behind develop
- Prevent release & hotfix branches being created at the same time
- Track active Pull Requests so prevent deployed changes from being rolled back
