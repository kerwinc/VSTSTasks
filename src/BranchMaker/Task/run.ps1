[CmdletBinding()]
param(
)

# Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$repository = Get-VstsInput -Name "repository" -Require
$env:TEAM_AuthType = Get-VstsInput -Name "authenticationType" -Require
$env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN
$stagingDirectory = $env:BUILD_STAGINGDIRECTORY

$build = New-Object psobject -Property @{
  BuildId            = $env:SYSTEM_DEFINITIONID
  SourceBranch       = ($env:BUILD_SOURCEBRANCH).Replace("refs/heads/", "")
  BuildReason        = $env:BUILD_REASON
  PullRequestId      = [System.Convert]::ToInt32($env:SYSTEM_PULLREQUEST_PULLREQUESTID)
  RepositoryProvider = $env:BUILD_REPOSITORY_PROVIDER
}

$taskProperties = New-Object psobject -Property @{
  SourceBranch  = Get-VstsInput -Name "sourceBranch" -Require
}

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectName]"
Write-Output "Build Reason: [$($build.BuildId)]"
Write-Output "Build Reason: [$($build.BuildReason)]"
Write-Output "Repository: [$repository]"
Write-Output "Current Branch: [$($Build.SourceBranch)]"
Write-Output "Authentication Type: [$env:TEAM_AUTHTYPE]"
Write-Output "Inputs:"
$taskProperties

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force

#Check if the source branch exists
$refs = Get-Branches -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository
$master = $refs.Value | Where-Object { $_.name -eq "refs/heads/$($taskProperties.SourceBranch)" }
if ($master -eq $null) {
  Write-Error "Could not find remote branch: refs/heads/$($taskProperties.SourceBranch)"
}


# Trace-VstsLeavingInvocation $MyInvocation