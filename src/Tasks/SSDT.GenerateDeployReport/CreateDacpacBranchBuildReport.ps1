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
$tempDirectory = "$env:BUILD_STAGINGDIRECTORY\temp"
$Branch = Get-VstsInput -Name "Branch" -Require
$ArtifactDropName = Get-VstsInput -Name "ArtifactDropName" -Require
$DacpacFile = Get-VstsInput -Name "DacpacFile" -Require
$PublishProfile = Get-VstsInput -Name "PublishProfile"
$AdditionalArguments = Get-VstsInput -Name "AdditionalArguments"
$CompareDirectory = Get-VstsInput -Name "CompareDirectory" -Require
$ReportDirectory = Get-VstsInput -Name "ReportDirectory" -Require
$SqlPackagePath = Get-VstsInput -Name "SqlPackagePath" -Require
$FailOnCompareBuildNotFound = [System.Convert]::ToBoolean($(Get-VstsInput -Name "FailOnCompareBuildNotFound" -Require))
$useWindowsAuthentication = [System.Convert]::ToBoolean($(Get-VstsInput -Name "UseWindowsAuthentication"))

$DatabaseName = "SchemaCompare"

$DacpacFileName = (Get-Item -LiteralPath $DacpacFile).Name
$DacpacPath = (Get-Item -LiteralPath $DacpacFile).Directory.FullName

Write-Host "DacpacName: [$DacpacFileName]"
Write-Host "DacpacPath: [$DacpacPath]"
Write-Host "CompareDirectory: [$CompareDirectory]"
Write-Host "ReportDirectory: [$ReportDirectory]"
Write-Host "ArtifactDropName: [$ArtifactDropName]"
Write-Host "SqlPackagePath: [$SqlPackagePath]"
Write-Host "BuildDefinitionId: [$BuildDefinitionId]"

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

# Load all dependent files for execution
# . "$scriptLocation\Utility.ps1"

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\File.Extensions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\team.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\Dacfx.Extensions.psm1" -Force -DisableNameChecking

if (-not $ProjectCollectionUri.EndsWith("/")) {
  $ProjectCollectionUri = $ProjectCollectionUri + '/'
}
$ProjectCollectionUri = $ProjectCollectionUri + $ProjectName + '/'

Remove-TeamAccount -Force
Write-Host "Addind account for $ProjectCollectionUri using Personal Access Token: $PersonalAccessToken"
if ($useWindowsAuthentication -eq $true) {
  Add-TeamAccount -Account $ProjectCollectionUri -UseWindowsAuthentication -Level Process
}
else {
  Add-TeamAccount -Account $ProjectCollectionUri -PersonalAccessToken $PersonalAccessToken -Level Process  
}

Write-Host "Getting the last successfull build for Build Definition Id: $BuildDefinitionId and branch: $Branch"
$build = Get-DefinitionBuilds -DefinitionId $BuildDefinitionId -Branch $Branch -StatusFilter completed -ResultFilter succeeded -top 1 -Verbose

if (($build -ne $null) -and ($build.id -gt 0) ) {
  if (-not(Test-DirectoryPath -Path $CompareDirectory)) {
    Write-Host "Creating directory: $CompareDirectory"
    New-Directory -Path $CompareDirectory
  }

  Write-Host "Build found for $Branch branch (Build Number = $($build.id). Looking for Artifact: $ArtifactDropName"
  $targetDacpac = Get-BuildArtifact -BuildId $Build.id -DropName $ArtifactDropName -ArtifactFileName $DacpacFileName -Destination $CompareDirectory
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
      Write-Host "Source Dacpac: [$sourceDacpac]"
      Write-Host "Target Dacpac: [$targetDacpac]"

      $deployReportFilePath = $("$ReportDirectory\DeployReport.$($build.buildNumber).xml")
      New-DeployReport -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $sourceDacpac -TargetDacpac $targetDacpac `
                       -PublishProfile $PublishProfile -OutputFilePath $deployReportFilePath -AdditionalArguments $AdditionalArguments

      Write-Host "Generateing Change Script..."
      $changeScriptFilePath = $("$ReportDirectory\ChangeScript.$($build.buildNumber).sql")
      New-SQLChangeScript -SqlPackagePath $SqlPackagePath -DatabaseName $DatabaseName -SourceDacpac $sourceDacpac -TargetDacpac $targetDacpac `
                          -PublishProfile $PublishProfile -OutputFilePath $changeScriptFilePath -AdditionalArguments $AdditionalArguments

      if (-not(Test-DirectoryPath -Path $tempDirectory)) {
        Write-Host "Creating directory: $tempDirectory"
        New-Directory -Path $tempDirectory
      }

      Convert-Report -ReportPath $deployReportFilePath -ReportXsltPath "$scriptLocation\report-transformToMd.xslt" -ChangeScriptFilePath $changeScriptFilePath  -OutputDirectory $tempDirectory

      Write-Host "Almost done, just making the deployment report look pretty..."
      $reportContent = Get-Content -LiteralPath "$scriptLocation\report-template.md"
      $deployReportContent = (Get-Content -LiteralPath "$tempDirectory\DeployReport.md") -join "`n"
      $reportContent = $reportContent.Replace("{{DeployReport}}", $deployReportContent)
      $reportContent = $reportContent.Replace("{{Branch}}", $Branch)
      $reportContent = $reportContent.Replace("{{BuildNumber}}", $Build.buildNumber)
      Set-Content -LiteralPath "$tempDirectory\DeployReport.md" -Value $reportContent

      Write-Host "Checking the deployment report for any alerts"
      [xml]$xml = Get-Content -LiteralPath $deployReportFilePath
      if ($xml -ne $null -and $xml.DeploymentReport -ne $null -and $xml.DeploymentReport.Alerts -ne $null) {
        foreach ($alert in $xml.DeploymentReport.Alerts.Alert) {
          Write-Warning "SSDT Alert: $($alert.Name) detected on $($alert.Issue.Value)"
        }
      }

      # Add the summary sections
      $summaryTitle = "Deployment report compared to $Branch branch (Build $($build.buildNumber))"
      Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name=$summaryTitle;]$tempDirectory\DeployReport.md"
      Write-Host "##vso[task.addattachment type=ChangeScript;name=ChangeScript;]$tempDirectory\ChangeScript.md"
    }
    else { 
      Write-Warning "Could not find $targetDacpac in the $Branch's build artifacts... Try building the $Branch branch first. Also make sure that the artifacts are published to the build."
    }
  }
}
else {
  Write-Warning "There doesnt seem to be a successful build for build definition:$BuildDefinitionId on branch: $Branch. So there isnt much this task can do here.. Its ok for this task to be skipped if the target branch has never been build."
  Write-Warning "Dacpac Compare: Could not find any successful builds on the $Branch branch!"
  if ($FailOnCompareBuildNotFound -eq $true) {
    Throw "Could not find a successful build on the $Branch branch. DacPac compare failed"
  }
}
Trace-VstsLeavingInvocation $MyInvocation