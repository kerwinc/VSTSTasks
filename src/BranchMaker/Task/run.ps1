[CmdletBinding()]
param(
)

Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$repositoryName = Get-VstsInput -Name "repository" -Require
$env:TEAM_AuthType = Get-VstsInput -Name "authenticationType" -Require
$env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN

$build = New-Object psobject -Property @{
  BuildId            = $env:SYSTEM_DEFINITIONID
  SourceBranch       = ($env:BUILD_SOURCEBRANCH).Replace("refs/heads/", "")
  BuildReason        = $env:BUILD_REASON
  PullRequestId      = [System.Convert]::ToInt32($env:SYSTEM_PULLREQUEST_PULLREQUESTID)
  RepositoryProvider = $env:BUILD_REPOSITORY_PROVIDER
}

$taskProperties = New-Object psobject -Property @{
  SourceBranchName  = Get-VstsInput -Name "sourceBranchName" -Require
  NewBranchName  = Get-VstsInput -Name "newBranchName" -Require
  ApplyBranchPolicy = [System.Convert]::ToBoolean((Get-VstsInput -Name "applyBranchPolicy" -Require))

  RequireMinimumReviewers = [System.Convert]::ToBoolean((Get-VstsInput -Name "requireMinimumReviewers" -Require))
  MinimumApproverCount = [System.Convert]::ToInt32((Get-VstsInput -Name "minimumApproverCount" -Require))
  CreatorVoteCounts = [System.Convert]::ToBoolean((Get-VstsInput -Name "creatorVoteCounts" -Require))
  AllowDownvotes = [System.Convert]::ToBoolean((Get-VstsInput -Name "allowDownvotes" -Require))
  ResetOnSourcePush = [System.Convert]::ToBoolean((Get-VstsInput -Name "resetOnSourcePush" -Require))

  checkForLinkedWorkItems = [System.Convert]::ToBoolean((Get-VstsInput -Name "checkForLinkedWorkItems" -Require))
  checkForLinkedWorkItemsType = Get-VstsInput -Name "checkForLinkedWorkItemsType" -Require

  checkForCommentResolution = [System.Convert]::ToBoolean((Get-VstsInput -Name "checkForCommentResolution" -Require))
  checkForCommentResolutionType = Get-VstsInput -Name "checkForCommentResolutionType" -Require

  enforceMergeStrategy = [System.Convert]::ToBoolean((Get-VstsInput -Name "enforceMergeStrategy" -Require))
  enforceMergeStrategyType = Get-VstsInput -Name "enforceMergeStrategyType" -Require
}

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectName]"
Write-Output "Build Reason: [$($build.BuildId)]"
Write-Output "Build Reason: [$($build.BuildReason)]"
Write-Output "Repository: [$repositoryName]"
Write-Output "Current Branch: [$($Build.SourceBranch)]"
Write-Output "Authentication Type: [$env:TEAM_AUTHTYPE]"
Write-Output "Task Inputs:"
$taskProperties

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force

$repository = Get-Repository -Repository $repositoryName
Write-Output "Repository Id: [$($repository.id)]"

$sourceBranchFullName = "refs/heads/$($taskProperties.SourceBranchName)"
$newBranchFullName = "refs/heads/$($taskProperties.NewBranchName)"

$branches = Get-Branches -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $($repository.Name)

Write-Output "Current Branches:"
$branches.Value | Select-Object name, objectId | Format-Table

Write-Output "Check if the source branch exists"
$sourceBranch = $branches.Value | Where-Object { $_.name -eq $sourceBranchFullName }
if ($null -eq $sourceBranch) {
  Write-Error "Could not find remote branch: $sourceBranchFullName"
}

Write-Output "Checking if the new branch [$newBranchFullName] exists"
if ($branches.Value | Where-Object { $_.name -eq $newBranchFullName }) {
  Write-Error "Branch already exists: $newBranchFullName"
}

Write-Output "Found source branch [$($sourceBranch.name)] with commit SHA [$($sourceBranch.objectId)]"

$result = New-Branch -Repository $repositoryName -BranchName $taskProperties.NewBranchName -NewObjectId $sourceBranch.objectId -Verbose
$result | Format-List
Write-Output "New branch created at [$($result.name)] using commit SHA [$($result.newObjectId)]"

if($taskProperties.ApplyBranchPolicy -eq $true) { 
  Write-Output "Applying Branch Policy"

  if($taskProperties.RequireMinimumReviewers -eq $true) { 
    $requreApprovalResult = Set-RequireApprovalPolicy -RepositoryId $repository.id -BranchName $taskProperties.NewBranchName -MinimumApproverCount $taskProperties.MinimumApproverCount -CreatorVoteCounts $taskProperties.CreatorVoteCounts -AllowDownvotes $taskProperties.AllowDownvotes -ResetOnSourcePush $taskProperties.ResetOnSourcePush
    Write-Output "Required approvals policy applied at $($requreApprovalResult.createdDate)"
  }

  if($taskProperties.checkForLinkedWorkItems -eq $true) {
    [bool]$isBlocking = $taskProperties.checkForLinkedWorkItemsType -eq "required"
    $requireWorkItemResult = Set-RequireWorkItemPolicy -RepositoryId $repository.id -BranchName $taskProperties.NewBranchName -IsBlocking $isBlocking
    Write-Output "Required workitem policy applied at $($requireWorkItemResult.createdDate)"
  }

  if($taskProperties.checkForCommentResolution -eq $true) {
    [bool]$isBlocking = $taskProperties.checkForCommentResolutionType -eq "required"
    $requireCommentResult = Set-RequireCommentResolutionPolicy -RepositoryId $repository.id -BranchName $taskProperties.NewBranchName -IsBlocking $isBlocking
    Write-Output "Required comment resolution policy applied at $($requireCommentResult.createdDate)"
  }
  
  if($taskProperties.enforceMergeStrategy -eq $true) {
    [bool]$useSquashMerge = $taskProperties.enforceMergeStrategyType -eq "squashMerge"
    $requireMergeStrategyResult = Set-RequireMergeStrategyPolicy -RepositoryId $repository.id -BranchName $taskProperties.NewBranchName -UseSquashMerge $useSquashMerge
    Write-Output "Enforce merge strategy policy applied at $($requireMergeStrategyResult.createdDate)"
  }
}

Trace-VstsLeavingInvocation $MyInvocation