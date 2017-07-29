param(
  [Parameter()][string]$ProjectCollectionUri = "http://devtfs02/DefaultCollection",
  [Parameter()][string]$ProjectName = "RnD",
  [Parameter()][string]$Branch = "master",
  [Parameter()][string]$ArtifactDropName = "drop",
  [Parameter()][string]$StatusFilter = "completed",
  [Parameter()][switch]$UseDefaultCredentials = $false,
  [Parameter()][string]$PersonalAccessToken = $env:SYSTEM_ACCESSTOKEN
)

$PersonalAccessToken = "m36nxou47z7myfq3hj3zk2m5pjfx5kqino2kjhmwjywlz3wqs7kq"
$definitionId = 4
$compareTempDirectory = "c:\temp\"
$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\Modules\File.Extensions.psm1" -Force
Import-Module "$scriptLocation\Modules\team.psm1" -Force
Import-Module "$scriptLocation\Modules\team.Extentions.psm1" -Force

if (-not $ProjectCollectionUri.EndsWith("/")) {
  $ProjectCollectionUri = $ProjectCollectionUri + '/'
}
$ProjectCollectionUri = $ProjectCollectionUri + $ProjectName + '/'

Remove-TeamAccount -Force
Add-TeamAccount -Account $ProjectCollectionUri -PersonalAccessToken $PersonalAccessToken -Level Process

Write-Host "Getting the last successfull build for Build Definition Id: $definitionId and branch: $Branch"
$build = Get-DefinitionBuilds -DefinitionId $DefinitionId -Branch $Branch -StatusFilter completed -ResultFilter succeeded -top 1 -Verbose

if ((-not $build) -or ($build -eq $null) -or ($build.id -le 0) ) {
  Write-Warning "There doesnt seem to be a successful build for build definition:$definitionId on branch: $Branch."
  Write-Warning "So there isnt much this task can do.. Consider failing the build at this point!"
}

$dacpacFilePath = Get-BuildArtifact -BuildId $Build.id -DropName $ArtifactDropName -DacpacName "RnD.SecurityDatabase" -Destination $compareTempDirectory
$dacpacFilePath
