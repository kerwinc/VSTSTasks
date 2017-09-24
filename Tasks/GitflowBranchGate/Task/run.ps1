[CmdletBinding()]
param(
)

Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$buildDefinitionId = $env:SYSTEM_DEFINITIONID
$repository = Get-VstsInput -Name "repository" -Require
$currentBranch = ($env:BUILD_SOURCEBRANCH).Replace("refs/heads/", "")
$env:TEAM_AuthType = Get-VstsInput -Name "authenticationType" -Require
$env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN
$stagingDirectory = $env:BUILD_STAGINGDIRECTORY

# $projectCollectionUri = "http://devtfs02/DefaultCollection"
# $projectName = "RnD"
# $repository = "RnD"
# $currentBranch = "develop"
# $env:TEAM_AUTHTYPE = "Basic"
# $env:TEAM_PAT = "OjVidjN6Mm1wM2ViYnB0ZnNuYmpxaWV2ajNidDJwcW9hM2xudTZmZnRkaXA2anNhem14NHE="

$rules = New-Object psobject -Property @{
  MasterBranch                                 = Get-VstsInput -Name "masterBranch" -Require
  DevelopBranch                                = Get-VstsInput -Name "developBranch" -Require
  HotfixPrefix                                 = Get-VstsInput -Name "hotfixBranches" -Require
  ReleasePrefix                                = Get-VstsInput -Name "releaseBranches" -Require
  FeaturePrefix                                = Get-VstsInput -Name "featureBranches" -Require

  HotfixBranchLimit                            = [System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchLimit" -Require))
  HotfixDaysLimit                              = [System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchDaysLimit" -Require))
  ReleaseBranchLimit                           = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchLimit" -Require))
  ReleaseDaysLimit                             = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchDaysLimit" -Require))
  FeatureBranchLimit                           = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchLimit" -Require))
  FeatureDaysLimit                             = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchDaysLimit" -Require))

  HotfixeBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixMustNotBeBehindMaster" -Require))
  ReleaseBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseMustNotBeBehindMaster" -Require))
  DevelopMustNotBeBehindMaster                 = [System.Convert]::ToBoolean((Get-VstsInput -Name "developMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindDevelop        = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindDevelop" -Require))
  CurrentFeatureMustNotBeBehindDevelop         = [System.Convert]::ToBoolean((Get-VstsInput -Name "CurrentFeatureMustNotBeBehindDevelop" -Require))
  MustNotHaveHotfixAndReleaseBranches          = [System.Convert]::ToBoolean((Get-VstsInput -Name "mustNotHaveHotfixAndReleaseBranches" -Require))
  MasterMustNotHaveActivePullRequests          = [System.Convert]::ToBoolean((Get-VstsInput -Name "masterMustNotHavePendingPullRequests" -Require))
  HotfixBranchesMustNotHaveActivePullRequests  = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixBranchesMustNotHavePendingPullRequests" -Require))
  ReleaseBranchesMustNotHaveActivePullRequests = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseBranchesMustNotHavePendingPullRequests" -Require))
  BranchNamesMustMatchConventions              = [System.Convert]::ToBoolean((Get-VstsInput -Name "branchNamesMustMatchConventions" -Require))
}
# $rules = New-Object psobject -Property @{
#   MasterBranch = "master"
#   DevelopBranch = "develop"
#   HotfixPrefix = "hotfix/*"
#   ReleasePrefix = "release/*"
#   FeaturePrefix = "feature/*"

#   HotfixBranchLimit = 1
#   HotfixDaysLimit = 10
#   ReleaseBranchLimit = 1
#   ReleaseDaysLimit = 10
#   FeatureBranchLimit = 50
#   FeatureDaysLimit = 45

#   HotfixeBranchesMustNotBeBehindMaster = $false
#   ReleaseBranchesMustNotBeBehindMaster = $false
#   DevelopMustNotBeBehindMaster = $false
#   FeatureBranchesMustNotBeBehindMaster = $false
#   FeatureBranchesMustNotBeBehindDevelop = $false
#   CurrentFeatureMustNotBeBehindDevelop = $false
#   MustNotHaveHotfixAndReleaseBranches = $false
#   MasterMustNotHaveActivePullRequests = $false
#   HotfixBranchesMustNotHaveActivePullRequests = $false
#   ReleaseBranchesMustNotHaveActivePullRequests = $false
#   BranchNamesMustMatchConventions = $false
# }

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

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\BranchRules.psm1" -Force

#Get All Branches
[System.Object[]]$pullRequests = Get-PullRequests -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -StatusFilter Active | ConvertTo-PullRequests
[System.Object[]]$branchesComparedToDevelop = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.DevelopBranch
[System.Object[]]$branches = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.MasterBranch | ConvertTo-Branches
$branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $branchesComparedToDevelop
$branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests
$branches = Invoke-BranchRules -Branches $branches -CurrentBranchName $currentBranch -Rules $rules

Write-OutputCurrentBranches -Branches $Branches
Write-OutputPullRequests -PullRequests $pullRequests
Write-OutputWarnings -Branches $Branches

$summaryTitle = "Gitflow Branch Gate Report"
$summaryFilePath = "$stagingDirectory\GitflowBranchGate.ReportSummary.md"
$reportFilePath = "$scriptLocation\Report.html"
Invoke-ReportSummary -Branches $branches -TemplatePath "$scriptLocation\ReportSummary.md" -ReportDestination $summaryFilePath
Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name=$summaryTitle;]$summaryFilePath"
Write-Host "##vso[artifact.upload containerfolder=Reports;artifactname=GitflowGateReports;]$reportFilePath"

Write-OutputErrors -Branches $Branches

Trace-VstsLeavingInvocation $MyInvocation