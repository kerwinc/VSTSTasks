### Background

This pipeline task provides the ability to create a new branch from the tip of another branch. This task is typically used for automating the creation of release branches with branch policies applied. This helps prevent commits from being pushed directly to release branches.

If you are using Trunk Based Development or Azure DevOps team's Release Flow approach to branch management, then this may make your life a little easier when creating new release branches.

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/feature/BranchMaker/src/BranchMaker/images/branchMaker_Task.png" alt="Task" style=""/>

### Getting Started

This task does not use git directly. All operations are done using the [Azure DevOps REST API](https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-5.0 "Azure DevOps REST API").

For this extension to work correctly, it's going to need a few super powers to be able to create a new branch and configure branch policies.
- Enable the "Allow scripts to access the OAuth token" on the pipeline phase
- Give the "Project Collection Build Service" the following permissions on the desired repository
    - Contribute (Allow)
    - Create branch (Allow)
    - Create tag (Allow)
    - Edit policies (Allow)

You can also apply these security changes to all git repositories in the project.

See:

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/feature/BranchMaker/src/BranchMaker/images/branchMaker_OAuthUserPermissions.png" alt="Permissions" style=""/>

### Key Features

- Allows a pipeline to create a new branch from any repo
- Apply branch basic policy settings to the new branch

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/feature/BranchMaker/src/BranchMaker/images/branchMaker_SetBranchPolicy.png" alt="Permissions" style=""/>

### Tips

#### Date Based Branch Names

For more dynamic branch names based on dates, use an inline PowerShell script to set a "BranchName" variable like so:

[Insert Image here]

Then use the variable in the Branch Maker step like so:

<img src="https://raw.githubusercontent.com/kerwinc/VSTSTasks/feature/BranchMaker/src/BranchMaker/images/BranchMaker_PowerShell_SetBranchNumber.png" alt="PowerShell Script" style=""/>

```powershell
`$date=$(Get-Date).ToString("yyyy.MM.dd");
Write-Host "##vso[task.setvariable variable=BranchName]$date"
````

### Release Notes

#### 0.1.0

- Initial Preview
