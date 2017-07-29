param(
  [Parameter()][string]$ProjectCollectionUri = "http://devtfs02/DefaultCollection",
  [Parameter()][string]$ProjectName = "RnD",
  [Parameter()][string]$Branch = "master",
  [Parameter()][string]$ArtifactDropName = "drop",
  [Parameter()][string]$DacpackPath,
  [Parameter()][string]$StatusFilter = "completed",
  [Parameter()][switch]$UseDefaultCredentials = $false,
  [Parameter()][string]$PersonalAccessToken = $env:SYSTEM_ACCESSTOKEN
)

$PersonalAccessToken = "m36nxou47z7myfq3hj3zk2m5pjfx5kqino2kjhmwjywlz3wqs7kq"
$definitionId = 4
$compareTempDirectory = $("$env:BUILD_BINARIESDIRECTORY\SchemaCompare")
# $compareTempDirectory = "c:\temp"
# $DacpackPath = "C:\Dev\devtfs02\RnD\src\RnD.SecurityDatabase\RnD.SecurityDatabase\bin\Debug\RnD.SecurityDatabase.dacpac"
$SqlPackagePath = "C:\Program Files\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe"
$DatabaseName = "SecurityDatabase"
$OutputPath = $env:BUILD_BINARIESDIRECTORY #"C:\temp\SchemaCompare"

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\Modules\File.Extensions.psm1" -Force
Import-Module "$scriptLocation\Modules\team.psm1" -Force
Import-Module "$scriptLocation\Modules\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\Modules\Dacfx.Extensions.psm1" -Force

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

$targetDacpac = Get-BuildArtifact -BuildId $Build.id -DropName $ArtifactDropName -DacpacName "RnD.SecurityDatabase" -Destination $compareTempDirectory
if ($targetDacpac -ne $null) {
  Write-Verbose -Verbose "Found source dacpac $targetDacpac"

  if ($DacpackPath -ne $null) {
    Write-Verbose -Verbose "Found target dacpac $($DacpackPath)"

    New-DeployReport -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $DacpackPath -TargetDacpac $targetDacpac -OutputPath $OutputPath -ExtraArgs $extraArgs
    New-SQLChangeScript -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $DacpackPath -TargetDacpac $targetDacpac -OutputPath $OutputPath -ExtraArgs $extraArgs

    Convert-Report -ReportPath $("$OutputPath\DeployReport.xml") -ReportXsltPath ".\report-transformToMd.xslt"

    # Add the summary sections
    Write-VstsAddAttachment -Type "Distributedtask.Core.Summary" -Name "Schema Change Summary - $dacpacName.dacpac" -Path "$OutputPath\deploymentReport.md"
    Write-VstsAddAttachment -Type "Distributedtask.Core.Summary" -Name "Change Script - $dacpacName.dacpac" -Path "$OutputPath\ChangeScript.md"
  }
}