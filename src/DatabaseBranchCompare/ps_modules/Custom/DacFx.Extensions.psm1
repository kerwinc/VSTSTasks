#SqlPackage.exe help: https://msdn.microsoft.com/library/hh550080(vs.103).aspx

function Execute-Command {
  param(
    [String][Parameter(Mandatory = $true)] $FileName,
    [String][Parameter(Mandatory = $true)] $Arguments
  )

  $ErrorActionPreference = 'Continue' 
  Invoke-Expression "& '$FileName' --% $Arguments" 2>&1 -ErrorVariable errors | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
      Write-Error $_
    }
    else {
      Write-Host $_
    }
  }
    
  foreach ($errorMsg in $errors) {
    Write-Error $errorMsg
  }
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) {
    throw  (Get-VstsLocString -Key "SQLDacpacTaskFailed")
  }
}

function New-DeployReport {
  param(
    [string]$SqlPackagePath,
    [string]$DatabaseName,
    [string]$SourceDacpac,
    [string]$TargetDacpac,
    [string]$PublishProfile,
    [string]$OutputFilePath,
    [string]$AdditionalArguments
  )

  $SourceDacpac = Resolve-Path -Path $SourceDacpac
  $TargetDacpac = Resolve-Path -Path $TargetDacpac

  Write-Host "Generating report: source = $SourceDacpac, target = $TargetDacpac"
  
  $scriptArgument = "/Action:DeployReport /SourceFile:`"$SourceDacpac`" /TargetFile:`"$TargetDacpac`" /TargetDatabaseName:`"$DatabaseName`" /OutputPath:`"$OutputFilePath`" /Profile:`"$PublishProfile`" $AdditionalArguments"
  $SqlPackageCommand = "`"$SqlPackagePath`" $scriptArgument"

  Write-Host "Executing : $SqlPackageCommand"
  Execute-Command -FileName $SqlPackagePath -Arguments $scriptArgument
}

function New-SQLChangeScript {
  param(
    [string]$SqlPackagePath,
    [string]$DatabaseName,
    [string]$SourceDacpac,
    [string]$TargetDacpac,
    [string]$PublishProfile,
    [string]$OutputFilePath,
    [string]$AdditionalArguments
  )

  $SourceDacpac = Resolve-Path -Path $SourceDacpac
  $TargetDacpac = Resolve-Path -Path $TargetDacpac

  Write-Host "Generating report: source = $SourceDacpac, target = $TargetDacpac"
  
  $scriptArgument = "/Action:Script /SourceFile:`"$SourceDacpac`" /TargetFile:`"$TargetDacpac`" /TargetDatabaseName:`"$DatabaseName`" /OutputPath:`"$OutputFilePath`" /Profile:`"$PublishProfile`" $AdditionalArguments"
  $SqlPackageCommand = "`"$SqlPackagePath`" $scriptArgument"

  Write-Host "Executing : $SqlPackageCommand"
  Execute-Command -FileName $SqlPackagePath -Arguments $scriptArgument
}

function Convert-Report {
  param(
    [string]$ReportPath,
    [string]$ReportXsltPath,
    [string]$ChangeScriptFilePath,
    [string]$OutputDirectory
  )

  Write-Verbose -Verbose "Converting report $ReportPath to md"
  $xslXml = [xml](Get-Content $ReportXsltPath)
  $reportXml = [xml](Get-Content $reportPath)

  $xslt = New-Object System.Xml.Xsl.XslCompiledTransform
  $xslt.Load($xslXml)
  $stream = New-Object System.IO.MemoryStream
  $xslt.Transform($reportXml, $null, $stream)
  $stream.Position = 0
  $reader = New-Object System.IO.StreamReader($stream)
  $text = $reader.ReadToEnd()
  
  $reportFolder = $(Get-Item -LiteralPath $ReportPath).Directory.FullName

  Write-Verbose -Verbose "Writing out transformed report to deploymentReport.md"
  Set-Content -Path $("$OutputDirectory\DeployReport.md") -Value $text
  $mdTemplate = "**Note**: Even if there are no schema changes, this script would still be run against the target environment. This usually includes
                some housekeeping code and any pre- and post-deployment scripts you may have in your database model.
                ``````
                {0}
                ``````
                "
  $md = $mdTemplate -f $(Get-Content $ChangeScriptFilePath -Raw)
  Set-Content -Path $("$OutputDirectory\ChangeScript.md") -Value $md
}