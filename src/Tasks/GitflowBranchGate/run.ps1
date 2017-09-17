[CmdletBinding()]
param(
)

Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$buildDefinitionId = $env:SYSTEM_DEFINITIONID
$personalAccessToken = $env:SYSTEM_ACCESSTOKEN
$repository = Get-VstsInput -Name "repository" -Require
$masterBranch = Get-VstsInput -Name "masterBranch" -Require

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectCollectionUri]"
Write-Output "Build Definition Id: [$buildDefinitionId]"
Write-Output "Repository: [$repository]"
Write-Output "Master Branch: [$masterBranch]"

Trace-VstsLeavingInvocation $MyInvocation