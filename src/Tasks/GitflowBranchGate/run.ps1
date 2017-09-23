[CmdletBinding()]
param(
)

# Trace-VstsEnteringInvocation $MyInvocation

# $projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
# $projectName = $env:SYSTEM_TEAMPROJECT
# $buildDefinitionId = $env:SYSTEM_DEFINITIONID
# $env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN
# $repository = Get-VstsInput -Name "repository" -Require
# $masterBranch = Get-VstsInput -Name "masterBranch" -Require
$rules = New-Object psobject -Property @{
  MasterBranchName = "master"
  DevelopBranchName = "develop"
  HotfixPrefix = "hotfix/*"
  ReleasePrefix = "release/*"
  FeaturePrefix = "feature/*"

  HotfixBranchLimit = 1
  HotfixDaysLimit = 10
  ReleaseBranchLimit = 1
  ReleaseDaysLimit = 10
  FeatureBranchLimit = 50
  FeatureDaysLimit = 45

  HotfixeBranchesMustNotBeBehindMaster = $true
  ReleaseBranchesMustNotBeBehindMaster = $true
  FeatureBranchesMustNotBeBehindMaster = $true
  FeatureBranchesMustNotBeBehindDevelop = $true
  MustNotHaveHotfixAndReleaseBranches = $true
  MasterMustNotHaveActivePullRequests = $true
  HotfixBranchesMustNotHaveActivePullRequests = $true
  ReleaseBranchesMustNotHaveActivePullRequests = $true
}

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectName]"
Write-Output "Build Definition Id: [$buildDefinitionId]"
Write-Output "Repository: [$repository]"
Write-Output "Master Branch: [$masterBranch]"
Write-Output "PAT: [$env:TEAM_PAT]"
$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

$projectCollectionUri = "http://devtfs02/DefaultCollection"
$projectName = "RnD"
$repository = "RnD"
$masterBranch = "master"
$currentBranch = "develop"
# $env:TEAM_PAT = "5bv3z2mp3ebbptfsnbjqievj3bt2pqoa3lnu6fftdip6jsazmx4q"
$env:TEAM_PAT = "OjVidjN6Mm1wM2ViYnB0ZnNuYmpxaWV2ajNidDJwcW9hM2xudTZmZnRkaXA2anNhem14NHE="

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\BranchRules.psm1" -Force

#Get All Branches
$pullRequests = Get-PullRequests -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -StatusFilter Active | ConvertTo-PullRequests
$branches = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $masterBranch | ConvertTo-Branches
$branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests

$branches = Invoke-BranchCommitRules -Branches $branches -CurrentBranchName $currentBranch -Rules $rules
# $branches | Format-Table *
# $branches | Select BranchName -ExpandProperty Errors | Where-Object {$_.Type -eq "Error"} | Format-List
$branches | Select BranchName -ExpandProperty Errors | Format-List

# $errorMessages = $branches | Where-Object { } | Select * | Format-List


# foreach($branch in $branches){
#   $branch.BranchName
#   $branch.Error | Format-List
# }

# Trace-VstsLeavingInvocation $MyInvocation