function New-DeployReport {
  param(
    [string]$SqlPackagePath,
    [string]$DatabaseName,
    [string]$SourceDacpac,
    [string]$TargetDacpac,
    [string]$OutputFilePath,
    [string]$BuildNumber,
    [string]$ExtraArgs
  )

  $SourceDacpac = Resolve-Path -Path $SourceDacpac
  $TargetDacpac = Resolve-Path -Path $TargetDacpac

  Write-Host "Generating report: source = $SourceDacpac, target = $TargetDacpac"
  & "$SqlPackagePath" /Action:DeployReport /SourceFile:$SourceDacpac `
    /TargetFile:$TargetDacpac /OutputPath:$OutputFilePath `
    /TargetDatabaseName:$DatabaseName /OverwriteFiles:True
  #   $commandArgs = "/a:{0} /sf:`"$SourceDacpac`" /tf:`"$TargetDacpac`" /tdn:Test /op:`"{1}`" {2}"
  #   $reportArgs = $commandArgs -f "DeployReport", "./SchemaCompare/SchemaCompare.xml", $ExtraArgs
  #   $reportCommand = "`"$SqlPackagePath`" $reportArgs"
  #   $reportCommand
  #   Invoke-Command -command $reportCommand
}

function New-SQLChangeScript {
  param(
    [string]$SqlPackagePath,
    [string]$DatabaseName,
    [string]$SourceDacpac,
    [string]$TargetDacpac,
    [string]$OutputFilePath,
    [string]$ExtraArgs
  )

  $SourceDacpac = Resolve-Path -Path $SourceDacpac
  $TargetDacpac = Resolve-Path -Path $TargetDacpac

  Write-Host "Generating report: source = $SourceDacpac, target = $TargetDacpac"
  & "$SqlPackagePath" /Action:Script /SourceFile:$SourceDacpac `
    /TargetFile:$TargetDacpac /OutputPath:$OutputFilePath `
    /TargetDatabaseName:$DatabaseName /OverwriteFiles:True
#   $scriptArgs = $commandArgs -f "Script", "./SchemaCompare/ChangeScript.sql", $ExtraArgs
#   $scriptCommand = "`"$SqlPackagePath`" $scriptArgs"
#   $scriptCommand
#   Invoke-Command -command $scriptCommand
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