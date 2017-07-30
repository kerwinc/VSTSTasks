[CmdletBinding()]
param(
  # [Parameter()][string]$Branch = "master",
  # [Parameter()][string]$ArtifactDropName = "drop",
  # [Parameter()][string]$DacpacFileName,
  # [Parameter()][string]$DacpacPath,
  # [Parameter()][string]$CompareDirectory,
  # [Parameter()][string]$ReportDirectory,
  # [Parameter()][string]$StatusFilter = "completed",
  # [Parameter()][string]$SqlPackagePath,
  # [Parameter()][switch]
)

Trace-VstsEnteringInvocation $MyInvocation

$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$ProjectName = $env:SYSTEM_TEAMPROJECT
$BuildDefinitionId = $env:SYSTEM_DEFINITIONID
$PersonalAccessToken = $env:SYSTEM_ACCESSTOKEN
# $UseDefaultCredentials = $false

$Branch = Get-VstsInput -Name "Branch" -Require
$ArtifactDropName = Get-VstsInput -Name "ArtifactDropName" -Require
$DacpacFileName = Get-VstsInput -Name "DacpacFileName" -Require
$DacpacPath = Get-VstsInput -Name "DacpacPath" -Require
$CompareDirectory = Get-VstsInput -Name "CompareDirectory" -Require
$ReportDirectory = Get-VstsInput -Name "ReportDirectory" -Require
$SqlPackagePath = Get-VstsInput -Name "SqlPackagePath" -Require

$DatabaseName = "SchemaCompare"

Write-Host "DacpacName: [$DacpacFileName]"
Write-Host "DacpacPath: [$DacpacPath]"
Write-Host "CompareDirectory: [$CompareDirectory]"
Write-Host "ReportDirectory: [$ReportDirectory]"
Write-Host "ArtifactDropName: [$ArtifactDropName]"
Write-Host "SqlPackagePath: [$SqlPackagePath]"
Write-Host "BuildDefinitionId: [$BuildDefinitionId]"

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\File.Extensions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\team.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\Dacfx.Extensions.psm1" -Force

if (-not $ProjectCollectionUri.EndsWith("/")) {
  $ProjectCollectionUri = $ProjectCollectionUri + '/'
}
$ProjectCollectionUri = $ProjectCollectionUri + $ProjectName + '/'

Remove-TeamAccount -Force
Write-Host "Addind account for $ProjectCollectionUri using Personal Access Token: $PersonalAccessToken"
Add-TeamAccount -Account $ProjectCollectionUri -PersonalAccessToken $PersonalAccessToken -Level Process

Write-Host "Getting the last successfull build for Build Definition Id: $BuildDefinitionId and branch: $Branch"
$build = Get-DefinitionBuilds -DefinitionId $BuildDefinitionId -Branch $Branch -StatusFilter completed -ResultFilter succeeded -top 1 -Verbose

if ((-not $build) -or ($build -eq $null) -or ($build.id -le 0) ) {
  Write-Warning "There doesnt seem to be a successful build for build definition:$BuildDefinitionId on branch: $Branch."
  Write-Warning "So there isnt much this task can do.. Consider failing the build at this point!"
}

if (-not(Test-DirectoryPath -Path $CompareDirectory)) {
  Write-Host "Creating directory: $CompareDirectory"
  New-Directory -Path $CompareDirectory
}

Write-Host "Build found for $Branch branch (Build Id = $($build.id). Looking for Artifact: $ArtifactDropName"
$targetDacpac = Get-BuildArtifact -BuildId $Build.id -DropName $ArtifactDropName -DacpacFileName $DacpacFileName -Destination $CompareDirectory
if ($targetDacpac -ne $null) {
  Write-Verbose -Verbose "Found source dacpac $targetDacpac"

  $sourceDacpac = $("$DacpacPath\$DacpacFileName")

  if ($sourceDacpac -ne $null) {
    Write-Verbose -Verbose "Found target dacpac $($sourceDacpac)"

    if (-not(Test-DirectoryPath -Path $ReportDirectory)) {
      Write-Host "Creating directory: $ReportDirectory"
      New-Directory -Path $ReportDirectory
    }

    Write-Host "Creating Deployment Report..."
    New-DeployReport -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $sourceDacpac -TargetDacpac $targetDacpac -OutputPath $ReportDirectory -ExtraArgs $extraArgs

    Write-Host "Generateing Change Script..."
    New-SQLChangeScript -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $sourceDacpac -TargetDacpac $targetDacpac -OutputPath $ReportDirectory -ExtraArgs $extraArgs

    Convert-Report -ReportPath $("$ReportDirectory\DeployReport.xml") -ReportXsltPath "$scriptLocation\report-transformToMd.xslt"

    # Add the summary sections
    $summaryTitle = "Deployment report compared to $Branch with build $($build.id)"
    Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name=$summaryTitle;]$ReportDirectory\DeployReport.md"
    Write-Host "##vso[task.addattachment type=myAttachmentType;name=ChangeScript;]$ReportDirectory\ChangeScript.md"
  }
}

Trace-VstsLeavingInvocation $MyInvocation