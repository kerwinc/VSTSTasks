[CmdletBinding()]
param(
)

Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$buildDefinitionId = $env:SYSTEM_DEFINITIONID
$repository = Get-VstsInput -Name "repository" -Require
$currentBranch = ($env:BUILD_SOURCEBRANCHNAME).Replace("refs/heads/", "")
$env:TEAM_AuthType = Get-VstsInput -Name "authenticationType" -Require
$env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN
# $env:TEAM_AUTHTYPE = "OAuthToken"
# $env:TEAM_PAT = "OjVidjN6Mm1wM2ViYnB0ZnNuYmpxaWV2ajNidDJwcW9hM2xudTZmZnRkaXA2anNhem14NHE="

$rules = New-Object psobject -Property @{
  MasterBranch = Get-VstsInput -Name "masterBranch" -Require
  DevelopBranch = Get-VstsInput -Name "developBranch" -Require
  HotfixPrefix = Get-VstsInput -Name "hotfixBranches" -Require
  ReleasePrefix = Get-VstsInput -Name "releaseBranches" -Require
  FeaturePrefix = Get-VstsInput -Name "featureBranches" -Require

  HotfixBranchLimit = [System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchLimit" -Require))
  HotfixDaysLimit =[System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchDaysLimit" -Require))
  ReleaseBranchLimit = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchLimit" -Require))
  ReleaseDaysLimit = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchDaysLimit" -Require))
  FeatureBranchLimit = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchLimit" -Require))
  FeatureDaysLimit = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchDaysLimit" -Require))

  HotfixeBranchesMustNotBeBehindMaster = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixMustNotBeBehindMaster" -Require))
  ReleaseBranchesMustNotBeBehindMaster = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseMustNotBeBehindMaster" -Require))
  DevelopMustNotBeBehindMaster = [System.Convert]::ToBoolean((Get-VstsInput -Name "developMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindMaster = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindDevelop = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindDevelop" -Require))
  CurrentFeatureMustNotBeBehindDevelop = [System.Convert]::ToBoolean((Get-VstsInput -Name "CurrentFeatureMustNotBeBehindDevelop" -Require))
  MustNotHaveHotfixAndReleaseBranches = [System.Convert]::ToBoolean((Get-VstsInput -Name "mustNotHaveHotfixAndReleaseBranches" -Require))
  MasterMustNotHaveActivePullRequests = [System.Convert]::ToBoolean((Get-VstsInput -Name "masterMustNotHavePendingPullRequests" -Require))
  HotfixBranchesMustNotHaveActivePullRequests = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixBranchesMustNotHavePendingPullRequests" -Require))
  ReleaseBranchesMustNotHaveActivePullRequests = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseBranchesMustNotHavePendingPullRequests" -Require))
  BranchNamesMustMatchConventions = [System.Convert]::ToBoolean((Get-VstsInput -Name "branchNamesMustMatchConventions" -Require))
}

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectName]"
Write-Output "Build Definition Id: [$buildDefinitionId]"
Write-Output "Repository: [$repository]"
Write-Output "Current Branch: [$currentBranch]"
Write-Output "Master Branch: [$($Rules.MasterBranch)]"
Write-Output "Authentication Type: [$env:TEAM_AUTHTYPE]"
Write-Output "Rules:"
$rules

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

# $projectCollectionUri = "http://devtfs02/DefaultCollection"
# $projectName = "RnD"
# $repository = "RnD"
# $currentBranch = "develop"
# $env:TEAM_PAT = "5bv3z2mp3ebbptfsnbjqievj3bt2pqoa3lnu6fftdip6jsazmx4q"

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\BranchRules.psm1" -Force

#Get All Branches
$pullRequests = Get-PullRequests -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -StatusFilter Active | ConvertTo-PullRequests
$branchesComparedToDevelop = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.DevelopBranch
$branches = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.MasterBranch | ConvertTo-Branches
$branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $branchesComparedToDevelop

Write-Output "`nCurrent Branches:"
Write-Output "------------------------------------------------------------------------------"
$branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests

$branches = Invoke-BranchRules -Branches $branches -CurrentBranchName $currentBranch -Rules $rules
$branches | Select-Object BranchName, Master, Develop, Modified, ModifiedBy, StaleDays | Format-Table

$warnings = $branches | Select-Object * -ExpandProperty Errors | Where-Object {$_.Type -eq "Warning"}
foreach($warning in $warnings){
  Write-Warning "Gitflow Branch Gate: $($warnings.Message)"
}

$errors = $branches | Select-Object -ExpandProperty Errors | Where-Object {$_.Type -eq "Error"}

Write-Output "`nBranch Gate Summary:"
Write-Output "Total Branches: $($branches.Count)"
Write-Output "Warnings: $($warnings.Count)"
Write-Output "Errors: $($errors.Count)"


if ($errors.Count -gt 0) {
  Write-Output "`nInvalid Branches:"
  Write-Output "------------------------------------------------------------------------------"
  $branches | Select-Object -ExpandProperty Errors | Where-Object {$_.Type -eq "Error" } | Select-Object BranchName, Master, Develop, Message | Sort-Object BranchName | Format-Table
  Write-Error "Current branches did not pass the Gitflow Branch Gate."
}
else {
  Write-Output "Branches passed the Gitflow Branch Gate. Nice."
}

Trace-VstsLeavingInvocation $MyInvocation