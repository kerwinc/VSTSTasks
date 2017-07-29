# Load common code
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

function _useWindowsAuthenticationOnPremise {
  return (_isOnWindows) -and (!$env:TEAM_PAT) -and -not ($env:TEAM_ACCT -like "*visualstudio.com")
}

function Invoke-GetCommand {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Url
  )
  Process {
    if (_useWindowsAuthenticationOnPremise ) {
      $responseFromGet = Invoke-RestMethod -Uri $Url -UseDefaultCredentials
      return $responseFromGet
    }
    else {
      $responseFromGet = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers @{Authorization = "Basic $env:TEAM_PAT"}
      return $responseFromGet
    }
  }
}

function Invoke-ArtifactDownload {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Uri,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$OutFile
  )
  Process {
    if (_useWindowsAuthenticationOnPremise ) {
      $responseFromGet = Invoke-WebRequest -Uri $Uri -UseDefaultCredentials -OutFile $OutFile
      return $responseFromGet
    }
    else {
      $responseFromGet = Invoke-WebRequest -Uri $Uri -Headers @{Authorization = "Basic $env:TEAM_PAT"}  -OutFile $OutFile
      return $responseFromGet
    }
  }
}

Function Get-DefinitionBuilds {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int]$DefinitionId,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Branch,
    [Parameter(ParameterSetName = 'List')]
    [ValidateSet('inProgress', 'completed', 'cancelling', 'postponed', 'notStarted', 'all')]
    [string] $StatusFilter,
    [Parameter(ParameterSetName = 'List')]
    [ValidateSet('succeeded', 'partiallySucceeded', 'failed', 'canceled')]
    [string] $ResultFilter,
    [Parameter(ParameterSetName = 'List')]
    [int] $Top = 5
  )
  Begin {
    if (-not $env:TEAM_ACCT) {
      throw 'You must call Add-TeamAccount before calling any other functions in this module.'
    }
  }
  Process {
    $url = $env:TEAM_ACCT + "/_apis/build/builds?definitions=$DefinitionId&statusFilter=$StatusFilter&resultFilter=$ResultFilter&api-version=2.0"
    $result = Invoke-GetCommand -Url $Url
    $jsonResult = $result.Value | Where-Object -Property sourceBranch -Value "refs/heads/$Branch" -EQ | Select-Object -Property Id, status, buildNumber, sourceBranch, result, definition -First $Top
    $jsonResult
  }
}

Function Get-VSTSBuild {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int] $BuildId
  )
  Process {

    $resultString = (Invoke-RestMethod -Uri "$baseUrl/_apis/build/builds/$BuildId/" -Headers @{Authorization = "Basic $env:TEAM_PAT"})
    $jsonResult = $resultString #| Select-Object -Property Id, status, buildNumber, sourceBranch, result -First $Top
    $jsonResult
  }
}

Function Get-BuildArtifacts {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int] $BuildId
  )
  Process {
    $url = $env:TEAM_ACCT + "/_apis/build/builds/$BuildId/artifacts"
    $result = Invoke-GetCommand -Url $Url
    return $result
  }
}

function Find-File {
  param(
    [string]$Path,
    [string]$FilePattern
  )

  Write-Verbose -Verbose "Searching for $FilePattern in $Path"
  $files = Find-VstsFiles -LiteralDirectory $Path -LegacyPattern $FilePattern

  if ($files -eq $null -or $files.GetType().Name -ne "String") {
    $count = 0
    if ($files -ne $null) {
      $count = $files.length
    }
    Write-Warning "Found $count matching files in folder. Expected a single file."
    $null
  }
  else {
    return $files
  }
}

Function Get-BuildArtifact {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int]$BuildId,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$DropName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$DacpacName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Destination
  )
  Process {
    Write-Host "Ok, so now we need to find the build artifacts for build Id: $definitionId"
    $artifacts = (Get-BuildArtifacts -BuildId $BuildId)
    if ($artifacts -eq $null -or [int]$($artifacts.count) -eq 0) {
      Write-Warning "No build artifacts found with the name '$DropName'"
      return
    }

    Write-Host "Found $($artifacts.count) artifact(s)..."
    $drop = $artifacts.value  | Where-Object {$_.name -eq $DropName}
    if ($drop -and $drop.resource) {
      Write-Host "Getting download Url..."
      
      # the drop is a file share
      if ($drop.resource.downloadUrl.StartsWith('file')) {
        if (Test-Path -LiteralPath $Destination) {
          Remove-Item -LiteralPath $Destination -Recurse -Force
        }
        mkdir $Destination
        $Destination = Resolve-Path -LiteralPath $Destination

        $uncPath = [System.Uri]($drop.resource.downloadUrl)
        Write-Host "Copying drop from server share $uncPath"
        Copy-Item -Path $uncPath.LocalPath -Destination $Destination -Recurse -Force
      }
      else {
        # the drop is a server drop
        Write-Host -Verbose "Downloading drop $($drop.resource.downloadUrl)"
        Invoke-ArtifactDownload -Uri $drop.resource.downloadUrl -OutFile "$Destination\$DropName.zip"
        $extractTempDirectory = Join-Path $Destination "TargetBuildArtifact"

        if (Test-DirectoryPath -Path $extractTempDirectory) {
          Write-Host "Removing directory: $extractTempDirectory"
          Remove-Directory -Path $extractTempDirectory
        }

        Write-Host "Extracting artifacts to $extractTempDirectory"
        ExtractZipFile -Zipfilename "$Destination\$DropName.zip" -Destination $extractTempDirectory

        Write-Host "Searching for $DacpacName.dacpac"
        $dacpac = Get-ChildItem -LiteralPath $extractTempDirectory -File -Filter "$DacpacName.dacpac" -Recurse
        if ($dacpac) {
          return $dacpac.FullName  
        }
        Write-Warning "Could not find any dacpac files with the name: $DacpacName"
        return
      }
    }
    else {
      Write-Warning "There is no drop with the name $DropName."
    }
  }
}



